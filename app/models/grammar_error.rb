class GrammarError < ApplicationRecord
  belongs_to :transcription
  has_many :grammar_corrections, dependent: :destroy

  validates :error_type, :error_description, :position, :length, presence: true
  validate :position_within_text_bounds

  # Validate that position and length are within the bounds of the transcription text
  def position_within_text_bounds
    return unless transcription && transcription.text_content.present?

    text_length = transcription.text_content.length

    if position.present? && position < 0
      errors.add(:position, "must be non-negative")
    end

    if position.present? && position >= text_length
      errors.add(:position, "must be within text bounds (#{position} >= #{text_length})")
    end

    if position.present? && length.present? && (position + length) > text_length
      errors.add(:length, "position + length (#{position + length}) exceeds text length (#{text_length})")
    end
  end

  # Common error types
  TYPES = [
    "verb_form",
    "concordance",
    "verb_tense",
    "preposition",
    "article",
    "word_order",
    "spelling",
    "punctuation",
    "other"
  ]

  # Get the text segment that contains the error
  def error_text
    transcription.text_content[position, length]
  end

  # Create a correction for this error
  def create_correction(corrected_text, explanation)
    grammar_corrections.create(
      corrected_text: corrected_text,
      explanation: explanation
    )
  end
end
