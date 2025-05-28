class GrammarAnalysisJob < ApplicationJob
  queue_as :default
  
  # Add logging tags to fix the tagged_logging error
  around_perform do |job, block|
    if Rails.logger.respond_to?(:tagged)
      Rails.logger.tagged("GrammarAnalysisJob") { block.call }
    else
      block.call
    end
  end

  def perform(transcription_id)
    Rails.logger.info("Starting GrammarAnalysisJob for transcription ID: #{transcription_id}")
    
    transcription = Transcription.find_by(id: transcription_id)
    
    if transcription.nil?
      Rails.logger.error("Transcription with ID #{transcription_id} not found")
      return
    end
    
    Rails.logger.info("Found transcription with text: #{transcription.text_content}")

    # Use the GrammarAnalysisService to analyze the text
    analyzer = GrammarAnalysisService.new(transcription)
    
    begin
      Rails.logger.info("Calling analyze method on GrammarAnalysisService")
      analyzer.analyze
      Rails.logger.info("Grammar analysis completed successfully for transcription ID: #{transcription_id}")
    rescue => e
      Rails.logger.error("Error during grammar analysis: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join('\n')}")
    end
  end
end
