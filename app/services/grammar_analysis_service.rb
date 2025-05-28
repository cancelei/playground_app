require 'net/http'
require 'uri'
require 'json'

class GrammarAnalysisService
  attr_reader :transcription

  def initialize(transcription)
    @transcription = transcription
  end

  def analyze
    # Skip if already analyzed
    return if transcription.analyzed?

    Rails.logger.info("Starting grammar analysis for transcription ID: #{transcription.id}")
    
    # Check if the transcription has text content
    if transcription.text_content.nil? || transcription.text_content.strip.empty?
      Rails.logger.error("Cannot analyze empty transcription text for ID: #{transcription.id}")
      return
    end
    
    Rails.logger.info("Text content to analyze: #{transcription.text_content}")
    
    begin
      # Use OpenAI API to analyze the text for grammar errors
      analyze_text(transcription.text_content)
      
      # Mark the transcription as analyzed
      if transcription.respond_to?(:analyzed_at=)
        transcription.update(analyzed_at: Time.current)
        Rails.logger.info("Updated transcription analyzed_at timestamp")
      else
        Rails.logger.warn("Transcription model does not have analyzed_at attribute, skipping timestamp update")
      end
      
      Rails.logger.info("Grammar analysis completed for transcription ID: #{transcription.id}")
    rescue => e
      Rails.logger.error("Error in grammar analysis: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join('\n')}")
    end
  end

  private

  def analyze_text(text)
    Rails.logger.info("Starting analyze_text with text length: #{text.length}")
    
    # Get grammar errors from OpenAI API
    grammar_errors = get_grammar_errors_from_openai(text)
    
    Rails.logger.info("Got #{grammar_errors.length} grammar errors from analysis")
    
    # Process each error and save to database
    grammar_errors.each_with_index do |error, index|
      Rails.logger.info("Processing error #{index + 1}: #{error[:type]} - #{error[:description]}")
      
      # Validate position and length before creating the error record
      if validate_error_position(text, error[:position], error[:length])
        # Create the error record
        grammar_error = transcription.grammar_errors.create(
          error_type: error[:type],
          error_description: error[:description],
          position: error[:position],
          length: error[:length]
        )
        
        if grammar_error.persisted?
          Rails.logger.info("Created grammar error record with ID: #{grammar_error.id}")
          
          # Create the correction
          if error[:correction].present?
            correction = grammar_error.create_correction(
              error[:correction][:text],
              error[:correction][:explanation]
            )
            
            if correction.persisted?
              Rails.logger.info("Created correction record with ID: #{correction.id}")
            else
              Rails.logger.error("Failed to create correction: #{correction.errors.full_messages.join(', ')}")
            end
          end
        else
          Rails.logger.error("Failed to create grammar error: #{grammar_error.errors.full_messages.join(', ')}")
        end
      else
        Rails.logger.error("Skipping error with invalid position/length: position=#{error[:position]}, length=#{error[:length]}, text length=#{text.length}")
      end
    end
    
    Rails.logger.info("Completed analyze_text. Total errors created: #{transcription.grammar_errors.count}")
  end
  
  # Helper method to validate error position and length
  def validate_error_position(text, position, length)
    return false unless position.is_a?(Integer) && length.is_a?(Integer)
    return false if position < 0 || length <= 0
    return false if position >= text.length
    return false if (position + length) > text.length
    true
  end

  def get_grammar_errors_from_openai(text)
    # Extract the API key from environment variables
    api_key = ENV['OPENAI_API_KEY']
    
    # Debug log for API key (masked for security)
    masked_key = api_key ? "#{api_key[0..5]}...#{api_key[-4..-1]}" : "nil"
    Rails.logger.info("OpenAI API Key (masked): #{masked_key}")
    
    raise "OpenAI API key not found. Please set the OPENAI_API_KEY environment variable." unless api_key

    # Set up the API request
    uri = URI.parse("https://api.openai.com/v1/chat/completions")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{api_key}"
    
    Rails.logger.info("Making request to OpenAI API endpoint: #{uri}")
    
    # Prepare the system prompt for grammar analysis
    system_prompt = "You are a grammar analysis tool. Analyze the input text for grammatical errors. "
    system_prompt += "For each error, return: "
    system_prompt += "1) Error type (e.g., verb_form, concordance, verb_tense, preposition, article, word_order, spelling, punctuation, other) "
    system_prompt += "2) Description of the issue "
    system_prompt += "3) Start position (0-based character index) "
    system_prompt += "4) Length of the erroneous text "
    system_prompt += "5) Corrected text  "
    system_prompt += "6) Explanation of the correction "
    system_prompt += "Respond strictly in the following JSON format: { \"errors\": [ { \"type\": \"error_type\", \"description\": \"error_description\", \"position\": number, \"length\": number, \"correction\": { \"text\": \"corrected_text\", \"explanation\": \"explanation_text\" } } ] }. "
    system_prompt += "If there are no errors, return: { \"errors\": [] }. Ensure the JSON structure and character positions are exact."

    # Set up the request body
    request_body = {
      model: "gpt-4",
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: text }
      ],
      temperature: 0.3  # Lower temperature for more consistent results
    }
    
    # Note: response_format parameter is not supported with all models
    # Only add it if using a model that supports it (like gpt-4-turbo)
    # request_body[:response_format] = { type: "json_object" }
    
    request.body = request_body.to_json
    
    Rails.logger.info("OpenAI request body: #{request.body}")
    
    # Send the request
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    begin
      Rails.logger.info("Sending request to OpenAI API...")
      response = http.request(request)
      Rails.logger.info("Received response with status code: #{response.code}")
      
      if response.code == "200"
        result = JSON.parse(response.body)
        Rails.logger.info("Successfully parsed JSON response")
        
        content = result["choices"][0]["message"]["content"]
        Rails.logger.info("Response content: #{content}")
        
        begin
          # Try to parse the content as JSON
          parsed_content = JSON.parse(content)
          Rails.logger.info("Parsed content: #{parsed_content.inspect}")
          
          if parsed_content.key?("errors")
            errors = parsed_content["errors"] || []
            Rails.logger.info("Found #{errors.length} grammar errors from OpenAI API")
          else
            # The model might not have returned the exact format we requested
            # Try to extract errors from the response in a different format
            Rails.logger.warn("Response JSON does not contain 'errors' key: #{parsed_content.keys.join(', ')}")
            
            # If it returned an array directly
            if parsed_content.is_a?(Array)
              Rails.logger.info("Response contains an array, trying to use it directly")
              errors = parsed_content
            else
              # Look for any key that might contain an array of errors
              array_keys = parsed_content.keys.select { |k| parsed_content[k].is_a?(Array) }
              if array_keys.any?
                Rails.logger.info("Found potential error arrays in keys: #{array_keys.join(', ')}")
                errors = parsed_content[array_keys.first] || []
              else
                errors = []
              end
            end
          end
          
          # If no errors were found but we expect there should be some, try the fallback
          if errors.empty? && text.length > 20
            Rails.logger.info("OpenAI found no errors, trying fallback analysis for verification")
            fallback_errors = fallback_grammar_analysis(text)
            
            if !fallback_errors.empty?
              Rails.logger.info("Fallback found #{fallback_errors.length} errors, using these instead")
              errors = fallback_errors
            end
          end
        end
        
        # Convert string keys to symbols
        errors.map do |error|
          error = error.transform_keys(&:to_sym)
          if error[:correction].is_a?(Hash)
            error[:correction] = error[:correction].transform_keys(&:to_sym)
          end
          error
        end
      else
        Rails.logger.error("OpenAI API error: #{response.body}")
        raise "Grammar analysis failed with status #{response.code}: #{response.body}"
      end
    rescue => e
      Rails.logger.error("Error during grammar analysis: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      # Fallback to basic error detection if API fails
      Rails.logger.info("Using fallback grammar analysis method")
      fallback_grammar_analysis(text)
    end
  end

  # Fallback method in case the API call fails
  def fallback_grammar_analysis(text)
    Rails.logger.info("Starting fallback grammar analysis for text: #{text}")
    errors = []
    
    # Basic patterns to detect common errors
    patterns = [
      { 
        regex: /\b(he|she|it)\s+(are|am|were)\b/i,
        type: 'concordance',
        description: 'Subject-verb agreement error',
        correction: lambda do |match, position|
          subject = match[1].downcase
          correct_verb = subject == 'he' || subject == 'she' || subject == 'it' ? 
            (match[2] == 'are' ? 'is' : 'was') : match[2]
          {
            text: match[0].gsub(match[2], correct_verb),
            explanation: "The verb should agree with the subject. '#{subject}' requires '#{correct_verb}' instead of '#{match[2]}'."
          }
        end
      },
      {
        regex: /\b(I|we|you|they)\s+(is|was)\b/i,
        type: 'concordance',
        description: 'Subject-verb agreement error',
        correction: lambda do |match, position|
          subject = match[1].downcase
          correct_verb = subject == 'i' || subject == 'we' || subject == 'you' || subject == 'they' ? 
            (match[2] == 'is' ? 'are' : 'were') : match[2]
          {
            text: match[0].gsub(match[2], correct_verb),
            explanation: "The verb should agree with the subject. '#{subject}' requires '#{correct_verb}' instead of '#{match[2]}'."
          }
        end
      },
      {
        regex: /\b(a)\s+([aeiou]\w+)\b/i,
        type: 'article',
        description: 'Incorrect article usage',
        correction: lambda do |match, position|
          {
            text: "an #{match[2]}",
            explanation: "Use 'an' before words that begin with a vowel sound."
          }
        end
      },
      {
        regex: /\b(an)\s+([^aeiou\s]\w+)\b/i,
        type: 'article',
        description: 'Incorrect article usage',
        correction: lambda do |match, position|
          {
            text: "a #{match[2]}",
            explanation: "Use 'a' before words that begin with a consonant sound."
          }
        end
      },
      {
        regex: /\b(I|he|she|it|we|you|they)\s+(has|have)\s+([a-z]+)\b/i,
        type: 'verb_form',
        description: 'Incorrect verb form',
        correction: lambda do |match, position|
          subject = match[1].downcase
          correct_verb = (subject == 'i' || subject == 'we' || subject == 'you' || subject == 'they') ? 'have' : 'has'
          if match[2].downcase != correct_verb
            {
              text: match[0].gsub(match[2], correct_verb),
              explanation: "The verb form should match the subject. '#{subject}' requires '#{correct_verb}'."
            }
          else
            # No correction needed
            {
              text: match[0],
              explanation: "No correction needed."
            }
          end
        end
      },
      {
        regex: /\b(dont|cant|wont|shouldnt|wouldnt|couldnt|isnt|arent|didnt)\b/i,
        type: 'punctuation',
        description: 'Missing apostrophe in contraction',
        correction: lambda do |match, position|
          contraction = match[0].downcase
          corrected = case contraction
                      when 'dont' then "don't"
                      when 'cant' then "can't"
                      when 'wont' then "won't"
                      when 'shouldnt' then "shouldn't"
                      when 'wouldnt' then "wouldn't"
                      when 'couldnt' then "couldn't"
                      when 'isnt' then "isn't"
                      when 'arent' then "aren't"
                      when 'didnt' then "didn't"
                      else match[0] # fallback
                      end
          {
            text: corrected,
            explanation: "Contractions require an apostrophe. '#{match[0]}' should be '#{corrected}'."
          }
        end
      }
    ]

    # Find errors in the text
    patterns.each do |pattern|
      Rails.logger.info("Checking pattern: #{pattern[:regex].inspect} (#{pattern[:type]})")
      text.scan(pattern[:regex]) do |match|
        match_data = Regexp.last_match
        position = match_data.begin(0)
        length = match_data[0].length
        matched_text = match_data[0]
        
        Rails.logger.info("Found match: '#{matched_text}' at position #{position}, length #{length}")
        
        correction = pattern[:correction].call(match_data, position)
        Rails.logger.info("Correction: #{correction[:text]}, Explanation: #{correction[:explanation]}")
        
        errors << {
          type: pattern[:type],
          description: pattern[:description],
          position: position,
          length: length,
          correction: correction
        }
      end
    end

    Rails.logger.info("Fallback analysis complete. Found #{errors.length} errors.")
    errors
  end
end
