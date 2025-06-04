class GrammarCorrection < ApplicationRecord
  belongs_to :grammar_error

  validates :corrected_text, :explanation, presence: true

  # Get the original error text
  def original_text
    grammar_error.error_text
  end

  # Get the full context of the correction
  def context
    text = grammar_error.transcription.text_content
    start_pos = [ 0, grammar_error.position - 20 ].max
    end_pos = [ text.length, grammar_error.position + grammar_error.length + 20 ].min

    text[start_pos...end_pos]
  end
end
