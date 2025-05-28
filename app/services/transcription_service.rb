require 'net/http'
require 'uri'
require 'json'

class TranscriptionService
  attr_reader :audio_data

  def initialize(audio_data)
    @audio_data = audio_data
  end

  def transcribe
    Rails.logger.info("Starting transcription process")
    
    # If the audio_data is a base64 string, convert it to a file
    if audio_data.is_a?(String) && audio_data.start_with?('data:')
      Rails.logger.info("Processing base64 audio data")
      transcribed_text = transcribe_with_openai(audio_data)
    elsif audio_data.respond_to?(:read)
      # If it's already a file, use it directly
      Rails.logger.info("Processing file audio data")
      transcribed_text = transcribe_with_openai(audio_data)
    else
      Rails.logger.error("Invalid audio data format: #{audio_data.class}")
      raise ArgumentError, "Invalid audio data format"
    end
    
    Rails.logger.info("Transcription completed. Text length: #{transcribed_text.length}")
    Rails.logger.info("Transcribed text: #{transcribed_text}")
    
    return transcribed_text
  end

  private

  def transcribe_with_openai(audio_data)
    # Extract the API key from environment variables
    api_key = ENV['OPENAI_API_KEY']
    raise "OpenAI API key not found. Please set the OPENAI_API_KEY environment variable." unless api_key

    # Prepare the audio file
    temp_file = prepare_audio_file(audio_data)
    
    # Set up the API request
    uri = URI.parse("https://api.openai.com/v1/audio/transcriptions")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{api_key}"
    
    # Create a multipart form
    form_data = [
      ['file', File.open(temp_file.path)],
      ['model', 'whisper-1'],
      ['response_format', 'json']
    ]
    
    request.set_form(form_data, 'multipart/form-data')
    
    # Send the request
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    begin
      response = http.request(request)
      
      if response.code == "200"
        result = JSON.parse(response.body)
        transcribed_text = result["text"]
        
        Rails.logger.info("Successfully received transcription from OpenAI")
        Rails.logger.info("Raw API response: #{result.inspect}")
        Rails.logger.info("Transcribed text: #{transcribed_text}")
        
        # Ensure we're not returning empty text
        if transcribed_text.nil? || transcribed_text.strip.empty?
          Rails.logger.error("Received empty transcription from OpenAI")
          raise "Transcription failed: Empty text returned from API"
        end
        
        return transcribed_text
      else
        Rails.logger.error("OpenAI API error: #{response.body}")
        raise "Transcription failed with status #{response.code}: #{response.body}"
      end
    rescue => e
      Rails.logger.error("Error during transcription: #{e.message}")
      raise e
    ensure
      # Clean up the temp file
      temp_file.close
      temp_file.unlink
    end
  end

  def prepare_audio_file(audio_data)
    if audio_data.is_a?(String) && audio_data.start_with?('data:')
      # Extract the base64 encoded audio data
      content_type = audio_data.match(/data:(.*);base64/)[1]
      base64_data = audio_data.split(',')[1]
      decoded_data = Base64.decode64(base64_data)
      
      # Create a temp file with the decoded data
      temp_file = Tempfile.new(['audio', '.webm'])
      temp_file.binmode
      temp_file.write(decoded_data)
      temp_file.rewind
      
      return temp_file
    else
      # If it's already a file, return it
      return audio_data
    end
  end
end
