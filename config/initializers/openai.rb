# OpenAI API configuration
require "dotenv/load" if Rails.env.development? || Rails.env.test?

# Validate that the OpenAI API key is set
if ENV["OPENAI_API_KEY"].blank? && (Rails.env.development? || Rails.env.production?)
  Rails.logger.warn "WARNING: OPENAI_API_KEY environment variable is not set. " \
                    "Audio transcription and grammar analysis features will not work properly."
else
  # Mask the API key for security in logs
  masked_key = ENV["OPENAI_API_KEY"] ? "#{ENV['OPENAI_API_KEY'][0..5]}...#{ENV['OPENAI_API_KEY'][-4..-1]}" : "nil"
  Rails.logger.info "OpenAI API Key loaded successfully (masked): #{masked_key}"

  # Check if the API key format is valid
  if ENV["OPENAI_API_KEY"] && !ENV["OPENAI_API_KEY"].start_with?("sk-")
    Rails.logger.warn "WARNING: OPENAI_API_KEY format may be incorrect. " \
                      "Standard OpenAI API keys start with 'sk-'. Check your .env file."
  end
end
