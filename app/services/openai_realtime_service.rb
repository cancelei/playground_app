require "websocket-client-simple"
require "httparty"
require "openai"
require "json"

class OpenaiRealtimeService
  # Constructor
  def initialize(config = {})
    @debug = config[:debug] || false
    @log_level = config[:log_level] || :info

    # Default to gpt-4o-mini-realtime-preview-2024-12-17 as it has better availability
    @model = config[:model] || "gpt-4o-mini-realtime-preview-2024-12-17"

    # Voice options from documentation
    @voice_options = [
      "alloy",   # Default neutral voice
      "echo",    # Lower pitch
      "fable",   # Soft, warm tone
      "onyx",    # Deep, authoritative
      "nova",    # Energetic, upbeat
      "shimmer", # Clear, crisp
      "verse"    # Versatile, adaptive
    ]
  end

  # Getter for the model
  def model
    @model
  end

  # Getter for the API key with validation
  def api_key
    api_key = ENV["OPENAI_API_KEY"]&.strip

    if api_key.blank?
      Rails.logger.error("OPENAI_API_KEY environment variable is not set or empty")
      return nil
    end

    # No need to log the actual key for security reasons
    Rails.logger.info("OPENAI_API_KEY is set and has length #{api_key.length}")
    api_key
  end

  # Get available voice options
  def voice_options
    @voice_options
  end

  # Create an ephemeral token for client-side WebRTC connections
  def create_ephemeral_token(voice: "verse")
    begin
      # Verify API key format and presence
      if api_key.blank?
        Rails.logger.error("API key is blank or missing")
        return { error: "API key is missing", status_code: 401 }
      end

      # Log the first few characters for debugging
      key_prefix = api_key[0..5]
      Rails.logger.info("Creating ephemeral token with API key: #{key_prefix}...")
      Rails.logger.info("Using model: #{model}, voice: #{voice}")

      # Ensure we're using a valid model name based on documentation
      current_model = case model
      when /preview/
        # If using preview name, switch to standard name
        "gpt-4o-mini-realtime-preview-2024-12-17"
      when "gpt-4o-mini-realtime-preview-2024-12-17", "gpt-4o-realtime"
        # These are valid model names in the docs
        model
      else
        # Default fallback
        "gpt-4o-mini-realtime-preview-2024-12-17"
      end

      Rails.logger.info("Using model: #{current_model}")

      # Validate voice is in the supported options
      unless @voice_options.include?(voice)
        Rails.logger.warn("Voice '#{voice}' not in documented options, using 'verse' instead")
        voice = "verse"
      end

      # Prepare request body according to the latest API documentation format
      request_body = {
        model: current_model,
        modalities: [ "audio", "text" ],
        instructions: "You are a friendly assistant."
      }

      # Add voice only if it's specifically needed in the API
      # Note: According to your example, voice may not be a top-level parameter anymore

      Rails.logger.info("Request body: #{request_body.to_json}")

      # Exactly match the endpoint and headers shown in the documentation
      response = HTTParty.post(
        "https://api.openai.com/v1/realtime/sessions",
        headers: {
          "Authorization" => "Bearer #{api_key}",
          "Content-Type" => "application/json",
          "OpenAI-Beta" => "realtime=v1"  # Required beta header as shown in docs
        },
        body: request_body.to_json
      )

      # Detailed logging for debugging
      Rails.logger.info("OpenAI API Response Status: #{response.code}")
      Rails.logger.info("Response headers: #{response.headers.inspect}")

      if response.success?
        begin
          parsed_response = JSON.parse(response.body)

          # Verify that the response contains the expected structure
          if parsed_response["client_secret"] && parsed_response["client_secret"]["value"]
            Rails.logger.info("Successfully obtained ephemeral token")
            parsed_response
          else
            Rails.logger.error("Response doesn't contain expected client_secret structure")
            Rails.logger.error("Response: #{parsed_response.inspect}")
            {
              error: "Invalid response structure",
              message: "Missing client_secret in response",
              status_code: 200,
              response: parsed_response
            }
          end
        rescue JSON::ParserError => e
          Rails.logger.error("Failed to parse response as JSON: #{e.message}")
          Rails.logger.error("Raw response: #{response.body}")
          {
            error: "Invalid response format",
            raw_response: response.body,
            status_code: response.code,
            details: e.message
          }
        end
      else
        # Handle different error codes specifically
        error_message = case response.code
        when 401
          "Authentication failed. Please check your OpenAI API key."
        when 403
          "Access denied. Your account may not have access to the Realtime API beta."
        when 404
          "API endpoint not found. The Realtime API may have changed."
        when 429
          "Rate limit exceeded. Please try again later."
        else
          "Request failed with status code #{response.code}"
        end

        error_body = begin
                      error_data = JSON.parse(response.body)
                      if error_data["error"]
                        error_message = error_data["error"]["message"] || error_data["error"]
                      end
                      error_data
                    rescue
                      { raw: response.body }
                    end

        Rails.logger.error("OpenAI API Error: #{error_message}")
        Rails.logger.error("Error details: #{error_body.inspect}")

        {
          error: error_message,
          message: error_body,
          status_code: response.code,
          headers: response.headers.to_h
        }
      end
    rescue => e
      Rails.logger.error("Exception creating ephemeral token: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      {
        error: "Exception",
        message: e.message,
        backtrace: e.backtrace
      }
    end
  end

  # Server-side proxy for SDP exchange to avoid CORS issues in the browser
  def proxy_sdp_exchange(ephemeral_token, sdp, type)
    begin
      Rails.logger.info("Proxying SDP exchange to OpenAI")

      # Validate inputs
      if ephemeral_token.blank? || sdp.blank? || type.blank?
        Rails.logger.error("Missing required parameters for SDP exchange")
        return { error: "Missing required parameters", status: 400 }
      end

      # Make request to OpenAI's connections endpoint for Realtime API
      Rails.logger.info("Using ephemeral token to connect to OpenAI's SDP endpoint")

      # Log detailed information for troubleshooting
      Rails.logger.info("Request details: URL=https://api.openai.com/v1/rtc/connections")
      Rails.logger.info("Request details: Headers={Authorization=Bearer #{ephemeral_token[0..5]}..., Content-Type=application/json, OpenAI-Beta=realtime=v1}")
      Rails.logger.info("Request details: Body contains SDP of length #{sdp.length}, type=#{type}")

      # Try alternative endpoint format based on documentation research
      # The endpoint might be different for WebRTC connections compared to session creation
      response = HTTParty.post(
        "https://api.openai.com/v1/rtc/connections",
        headers: {
          "Authorization" => "Bearer #{ephemeral_token}",
          "Content-Type" => "application/json",
          "OpenAI-Beta" => "realtime=v1"
        },
        body: JSON.generate({
          sdp: sdp,
          type: type
        }),
        timeout: 15,  # Extended timeout for network latency
        debug_output: $stdout  # Enable full HTTP debugging
      )

      Rails.logger.info("SDP exchange response status: #{response.code}")

      if response.success?
        { sdp: response.body, status: 200 }
      else
        error_message = "SDP exchange failed: #{response.code} #{response.message}"
        Rails.logger.error(error_message)
        { error: error_message, status: response.code }
      end

    rescue => e
      error_message = "Exception in SDP exchange: #{e.message}"
      Rails.logger.error(error_message)
      Rails.logger.error(e.backtrace.join("\n"))
      { error: error_message, status: 500 }
    end
  end

  # For server-side WebSocket connections
  def create_websocket_connection(&block)
    url = "wss://api.openai.com/v1/realtime?model=#{model}"

    ws = WebSocket::Client::Simple.connect(url, {
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "OpenAI-Beta" => "realtime=v1"
      }
    })

    # Set up event handlers
    ws.on :open do
      Rails.logger.info("Connected to OpenAI Realtime API")
      yield(ws, :open, nil) if block_given?
    end

    ws.on :message do |message|
      begin
        data = JSON.parse(message.data.to_s)
        Rails.logger.debug("Received from OpenAI: #{data}")
        yield(ws, :message, data) if block_given?
      rescue => e
        Rails.logger.error("Error parsing message: #{e.message}")
        yield(ws, :error, e) if block_given?
      end
    end

    ws.on :error do |e|
      Rails.logger.error("WebSocket Error: #{e.message}")
      yield(ws, :error, e) if block_given?
    end

    ws.on :close do |e|
      Rails.logger.info("WebSocket connection closed: #{e}")
      yield(ws, :close, e) if block_given?
    end

    ws
  end

  # For transcription-only use case via WebSockets
  def create_transcription_connection(&block)
    url = "wss://api.openai.com/v1/realtime?intent=transcription"

    ws = WebSocket::Client::Simple.connect(url, {
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "OpenAI-Beta" => "realtime=v1"
      }
    })

    # Set up event handlers
    ws.on :open do
      Rails.logger.info("Connected to OpenAI Transcription API")
      yield(ws, :open, nil) if block_given?
    end

    ws.on :message do |message|
      begin
        data = JSON.parse(message.data.to_s)
        Rails.logger.debug("Received transcription: #{data}")
        yield(ws, :message, data) if block_given?
      rescue => e
        Rails.logger.error("Error parsing transcription message: #{e.message}")
        yield(ws, :error, e) if block_given?
      end
    end

    ws.on :error do |e|
      Rails.logger.error("Transcription WebSocket Error: #{e.message}")
      yield(ws, :error, e) if block_given?
    end

    ws.on :close do |e|
      Rails.logger.info("Transcription WebSocket connection closed: #{e}")
      yield(ws, :close, e) if block_given?
    end

    ws
  end

  # Helper to send events through the WebSocket
  def send_event(ws, event_type, data = {})
    event = { type: event_type }.merge(data)
    ws.send(event.to_json)
  end
end
