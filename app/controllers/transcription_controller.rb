class TranscriptionController < ApplicationController
  def index
    @transcriptions = Transcription.order(created_at: :desc).limit(10)
  end

  def create
    Rails.logger.info("Creating new transcription with params: #{transcription_params.to_h.except(:audio_data)}")
    
    @transcription = Transcription.new(transcription_params)
    
    # Log audio data presence
    if transcription_params[:audio_data].present?
      Rails.logger.info("Audio data is present in the request")
      audio_data_length = transcription_params[:audio_data].length
      Rails.logger.info("Audio data length: #{audio_data_length} characters")
    else
      Rails.logger.warn("No audio data present in the request")
    end
    
    if @transcription.save
      Rails.logger.info("Transcription saved successfully with ID: #{@transcription.id}")
      Rails.logger.info("Transcription text content: #{@transcription.text_content}")
      
      # Check if audio file was attached
      if @transcription.audio_file.attached?
        Rails.logger.info("Audio file successfully attached to transcription")
        Rails.logger.info("Audio file content type: #{@transcription.audio_file.content_type}")
        Rails.logger.info("Audio file size: #{@transcription.audio_file.byte_size} bytes")
      else
        Rails.logger.warn("No audio file attached to transcription")
      end
      
      # Process the transcription with grammar analysis
      begin
        if Rails.env.development?
          # In development, perform the job immediately for faster feedback
          Rails.logger.info("Running grammar analysis job immediately (development mode)")
          GrammarAnalysisJob.perform_now(@transcription.id)
        else
          # In production, use background processing
          Rails.logger.info("Enqueueing grammar analysis job (production mode)")
          GrammarAnalysisJob.perform_later(@transcription.id)
        end
      rescue => e
        Rails.logger.error("Error processing grammar analysis job: #{e.message}")
        Rails.logger.error("Backtrace: #{e.backtrace.join('\n')}")
        # Continue with the response even if the job fails
      end
      
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to transcription_show_path(@transcription) }
      end
    else
      Rails.logger.error("Failed to save transcription: #{@transcription.errors.full_messages.join(', ')}")
      render :index, status: :unprocessable_entity
    end
  end

  def show
    @transcription = Transcription.find(params[:id])
  end
  
  # API endpoint for transcribing audio
  def transcribe
    begin
      Rails.logger.info("Received transcription request")
      
      # Get the audio data from the request
      audio_data = params[:audio_data]
      
      if audio_data.nil? || audio_data.empty?
        Rails.logger.error("No audio data received in request")
        render json: { error: "No audio data provided" }, status: :bad_request
        return
      end
      
      # Log audio data format
      if audio_data.is_a?(String) && audio_data.include?('base64')
        Rails.logger.info("Received base64 audio data, length: #{audio_data.length} characters")
        content_type = audio_data.match(/data:(.*);base64/)[1]
        Rails.logger.info("Audio content type: #{content_type}")
      elsif audio_data.respond_to?(:content_type)
        Rails.logger.info("Received file upload, content type: #{audio_data.content_type}")
      else
        Rails.logger.info("Received audio data of type: #{audio_data.class}")
      end
      
      Rails.logger.info("Starting transcription process")
      
      # Use the TranscriptionService to transcribe the audio
      transcription_service = TranscriptionService.new(audio_data)
      transcribed_text = transcription_service.transcribe
      
      Rails.logger.info("Transcription successful, text length: #{transcribed_text.length}")
      Rails.logger.info("Transcribed text: #{transcribed_text}")
      
      # Return the transcribed text as JSON
      render json: { text: transcribed_text }
    rescue => e
      Rails.logger.error("Error during transcription: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join('\n')}")
      render json: { error: "Transcription failed: #{e.message}" }, status: :unprocessable_entity
    end
  end

  private

  def transcription_params
    params.require(:transcription).permit(:audio_data, :text_content)
  end
end
