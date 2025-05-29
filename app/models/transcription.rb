class Transcription < ApplicationRecord
  has_many :grammar_errors, dependent: :destroy
  has_many :grammar_corrections, through: :grammar_errors
  
  validates :text_content, presence: true
  
  # For handling audio uploads
  has_one_attached :audio_file
  
  # Method to process the audio data from base64
  def audio_data=(data)
    return unless data.present?
    
    # Extract the base64 encoded audio data
    if data.include?('base64')
      begin
        # Extract content type and data
        content_type = data.match(/data:(.*);base64/)[1]
        base64_data = data.split(',')[1]
        decoded_data = Base64.decode64(base64_data)
        
        # Log the decoded data size
        Rails.logger.info("Decoded audio data size: #{decoded_data.bytesize} bytes")
        
        # Normalize content type - ensure we're using a widely supported format
        # WebM is widely supported for audio in browsers
        normalized_content_type = 'audio/webm'
        
        # Create a filename with the correct extension based on content type
        extension = case normalized_content_type
                    when 'audio/webm' then 'webm'
                    when 'audio/mp4', 'audio/mp4a-latm' then 'mp4'
                    when 'audio/mpeg' then 'mp3'
                    when 'audio/ogg', 'audio/opus' then 'ogg'
                    else 'webm' # Default to webm
                    end
        
        filename = "audio_#{Time.current.to_i}.#{extension}"
        
        # Purge any existing audio file to avoid duplicates
        audio_file.purge if audio_file.attached?
        
        # Write to a temporary file to ensure proper handling
        temp_file = Tempfile.new(["audio", ".#{extension}"])
        temp_file.binmode
        temp_file.write(decoded_data)
        temp_file.rewind
        
        # Attach the file using the temp file to ensure data is properly stored
        audio_file.attach(
          io: temp_file,
          filename: filename,
          content_type: normalized_content_type
        )
        
        # Ensure the attachment was successful
        if audio_file.attached?
          Rails.logger.info("Audio file attached successfully: #{filename}")
          Rails.logger.info("Audio file content type: #{audio_file.content_type}")
          Rails.logger.info("Audio file byte size: #{audio_file.byte_size}")
        else
          Rails.logger.error("Failed to attach audio file")
        end
        
        # Clean up the temp file
        temp_file.close
        temp_file.unlink
      rescue => e
        Rails.logger.error("Error processing audio data: #{e.message}")
        Rails.logger.error("Backtrace: #{e.backtrace.join('\n')}")
      end
    else
      Rails.logger.warn("Audio data does not contain base64 encoding")
    end
  end
  
  # Check if this transcription has been analyzed for grammar errors
  def analyzed?
    # Check either if we have a timestamp or if we have grammar errors
    analyzed_at.present? || grammar_errors.any?
  end
  
  # Get corrected version of the text
  def corrected_text
    return text_content unless analyzed?
    
    corrected = text_content.dup
    
    # Apply corrections in reverse order of position to avoid offset issues
    grammar_errors.order(position: :desc).each do |error|
      if error.grammar_corrections.any?
        correction = error.grammar_corrections.first
        corrected[error.position, error.length] = correction.corrected_text
      end
    end
    
    corrected
  end
  
  # Get a clean version of the corrected text for display
  def clean_corrected_text
    return text_content unless analyzed?
    
    # Create a completely new string with all corrections applied
    # We need to handle overlapping errors carefully
    
    # First, get all errors with their corrections
    errors_with_corrections = grammar_errors.includes(:grammar_corrections)
      .select { |error| error.grammar_corrections.any? }
      .map do |error|
        {
          position: error.position,
          length: error.length,
          end_pos: error.position + error.length,
          correction: error.grammar_corrections.first.corrected_text
        }
      end
    
    # If no corrections, return the original text
    return text_content if errors_with_corrections.empty?
    
    # Sort by position
    errors_with_corrections.sort_by! { |e| e[:position] }
    
    # Check for overlapping errors and remove them
    non_overlapping = []
    current_end = -1
    
    errors_with_corrections.each do |error|
      if error[:position] >= current_end
        non_overlapping << error
        current_end = error[:end_pos]
      else
        Rails.logger.warn("Skipping overlapping error at position #{error[:position]}")
      end
    end
    
    # Build the corrected text
    result = ""
    current_pos = 0
    
    non_overlapping.each do |error|
      # Add text before this error
      if error[:position] > current_pos
        result += text_content[current_pos...error[:position]]
      end
      
      # Add the correction
      result += error[:correction]
      
      # Update current position
      current_pos = error[:end_pos]
    end
    
    # Add any remaining text
    if current_pos < text_content.length
      result += text_content[current_pos..]
    end
    
    # Log the result for debugging
    Rails.logger.debug("Original text: #{text_content}")
    Rails.logger.debug("Corrected text: #{result}")
    
    result
  end
end
