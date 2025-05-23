class RealtimeController < ApplicationController
  # Skip CSRF protection for API endpoints
  skip_forgery_protection only: [ :create_session, :process_audio, :sdp_exchange, :create_conversation_turn ]
  # GET /realtime
  # Main page with WebRTC implementation for client-side
  def index
    # Available model options - updated to latest versions
    @model_options = [
      "gpt-4o-mini-realtime-preview-2024-12-17",  # More reliable option
      "gpt-4o-realtime-preview-2024-12-17",       # Stronger option
    ]

    @voice_options = [
      "alloy",   # Default neutral voice
      "echo",    # Lower pitch
      "fable",   # Soft, warm tone
      "onyx",    # Deep, authoritative
      "nova",    # Energetic, upbeat
      "shimmer", # Clear, crisp
      "verse"    # Versatile, adaptive
    ]

    # Load conversation turns for the session (placeholder session_id for now)
    @conversation_turns = ConversationTurn.where(session_id: 'demo').order(:created_at)

    # Provide info about the API key being used
    api_key = ENV["OPENAI_API_KEY"]
    @api_key_info = {
      present: api_key.present?,
      prefix: api_key.present? ? api_key[0..5] : nil,
      length: api_key&.length
    }
  end

  # POST /realtime/session
  # Endpoint to create ephemeral token for WebRTC
  def create_session
    begin
      # Support a debug parameter that forces mock data for testing
      use_mock = params[:debug] == "true" || params[:debug] == true

      if use_mock
        Rails.logger.info("Using MOCK response for debugging (debug=true)")
        render json: {
          debug_mode: true,
          client_secret: { value: "mock_ephemeral_key_for_testing" },
          model: params[:model] || "gpt-4o-mini-realtime-preview-2024-12-17-preview-2024-12-17",
          voice: params[:voice] || "verse"
        }
        return
      end

      Rails.logger.info("Creating real OpenAI session with model: #{params[:model]}, voice: #{params[:voice]}")

      # Use our OpenaiRealtimeService to get a real ephemeral token
      service = OpenaiRealtimeService.new(
        model: params[:model] || "gpt-4o-mini-realtime-preview-2024-12-17-preview-2024-12-17"
      )

      token_response = service.create_ephemeral_token(voice: params[:voice] || "verse")

      if token_response[:error].present?
        Rails.logger.error("Error from OpenAI API: #{token_response[:error]}")

        # If the API key seems invalid or missing permissions, log a helpful message
        if token_response[:status_code] == 401 || token_response[:error].to_s.include?("unauthorized")
          Rails.logger.error("=============================")
          Rails.logger.error("API KEY ISSUE: Your API key may not have access to the Realtime API")
          Rails.logger.error("Make sure your account is approved for the OpenAI Realtime API beta")
          Rails.logger.error("If you need to test the UI, use debug=true parameter")
          Rails.logger.error("=============================")
        end

        render json: token_response, status: :service_unavailable
      else
        Rails.logger.info("Successfully created OpenAI ephemeral token")
        render json: token_response
      end
    rescue => e
      Rails.logger.error("Exception in create_session: #{e.message}")
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  # GET /realtime/websocket
  # Demo page with WebSocket implementation (server-side)
  def websocket
    # Pass model options to the view for server-side implementation
    @model_options = [
      "gpt-4o-mini-realtime-preview-2024-12-17-preview-2024-12-17"
    ]
  end

  # GET /realtime/transcription
  # Demo page with transcription-only implementation
  def transcription
    # Pass transcription model options to the view
    @model_options = [
      "gpt-4o-mini-transcribe"
    ]
  end

  # POST /realtime/sdp_exchange
  # Server-side proxy for SDP exchange with OpenAI to bypass CORS
  def sdp_exchange
    begin
      Rails.logger.info("SDP exchange proxy request received")

      # Extract required parameters from the request
      ephemeral_token = params[:ephemeral_token]
      sdp = params[:sdp]
      type = params[:type]

      # Add detailed debugging but don't log sensitive data
      token_prefix = ephemeral_token.present? ? ephemeral_token[0..5] : "nil"
      Rails.logger.info("SDP exchange parameters: token_prefix=#{token_prefix}..., type=#{type}, sdp_length=#{sdp&.length || 0}")

      # Validate required parameters
      unless ephemeral_token.present? && sdp.present? && type.present?
        Rails.logger.error("Missing required parameters for SDP exchange")
        render json: { error: "Missing required parameters" }, status: :bad_request
        return
      end

      # Create an instance of the OpenAI Realtime service
      service = OpenaiRealtimeService.new

      # Call the proxy method to handle the SDP exchange
      result = service.proxy_sdp_exchange(ephemeral_token, sdp, type)

      if result[:error].present?
        Rails.logger.error("SDP exchange error: #{result[:error]}")
        render json: { error: result[:error] }, status: result[:status] || :service_unavailable
      else
        Rails.logger.info("SDP exchange completed successfully")
        render json: { sdp: result[:sdp] }
      end
    rescue => e
      Rails.logger.error("Exception in sdp_exchange: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  # POST /realtime/process_audio
  # Process audio recording through server-side WebSocket
  def process_audio
    begin
      audio_file = params[:audio]

      if audio_file.nil?
        return render json: { error: "No audio file provided" }, status: :bad_request
      end

      # Create a temporary file to store the audio
      temp_file = Tempfile.new([ "audio", ".wav" ])
      temp_file.binmode
      temp_file.write(audio_file.read)
      temp_file.rewind

      # Process the audio through our service
      service = OpenaiRealtimeService.new(
        model: params[:model] || "gpt-4o-mini-realtime-preview-2024-12-17-preview-2024-12-17"
      )

      # Results to return to client
      transcript = nil
      ai_response = nil

      # Connect to OpenAI via WebSocket
      ws = service.create_websocket_connection do |socket, event_type, data|
        case event_type
        when :open
          # When connection opens, send the audio file content as binary data
          socket.send(temp_file.read, type: :binary)
        when :message
          if data && data["type"] == "transcript" && data["transcript"] && data["transcript"]["text"]
            # Store transcript result
            transcript = data["transcript"]["text"] if data["transcript"]["final"]
          elsif data && data["type"] == "message" && data["message"] && data["message"]["content"]
            # Store AI response
            content = data["message"]["content"]
            ai_response = content["text"] if content["text"]
          end
        when :error, :close
          # Handle connection close or errors
          break
        end
      end

      # Allow the WebSocket to process for a few seconds
      sleep 3

      # Clean up
      ws.close if ws.respond_to?(:close)
      temp_file.close
      temp_file.unlink

      render json: {
        transcript: transcript || "No transcript available",
        ai_response: ai_response
      }
    rescue => e
      Rails.logger.error("Error processing audio: #{e.message}")
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  # POST /realtime/conversation_turns
  def create_conversation_turn
    @conversation_turn = ConversationTurn.new(
      role: params[:role],
      content: params[:content],
      session_id: params[:session_id] || 'demo'
    )
    if @conversation_turn.save
      respond_to do |format|
        format.html { head :ok }
        format.json { render json: @conversation_turn, status: :created }
      end
    else
      head :unprocessable_entity
    end
  end
end
