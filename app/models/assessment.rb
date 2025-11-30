# frozen_string_literal: true

# Assessment model for clinical mental health screening
# Stores PHQ-A and GAD-7 responses with scoring
#
# Status State Machine: nil -> in_progress -> complete
# Story 5.1: Conversational Screening Questions
class Assessment < ApplicationRecord
  include Encryptable
  include Auditable

  # Associations
  belongs_to :onboarding_session

  # PHI Encryption
  # AC 2.6.6: Assessment responses contain sensitive health information
  # Story 5.1: Summary also contains PHI
  encrypts_phi :responses, :summary

  # Status enum
  # Story 5.1: Assessment status state machine
  enum :status, {
    not_started: 0,
    in_progress: 1,
    complete: 2
  }

  # Validations
  validates :responses, presence: true
  validates :consent_given, inclusion: { in: [true, false] }
  validates :onboarding_session, presence: true
  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  # State transition validation
  validate :valid_status_transition, on: :update, if: :status_changed?

  # Scopes
  scope :in_progress, -> { where(status: :in_progress) }
  scope :completed, -> { where(status: :complete) }

  # Get parsed responses
  #
  # @return [Hash] Parsed responses with phq_a, gad_7, progress, scores
  def parsed_responses
    return {} if responses.blank?

    case responses
    when Hash
      responses.deep_symbolize_keys
    when String
      JSON.parse(responses).deep_symbolize_keys
    else
      {}
    end
  rescue JSON::ParserError
    {}
  end

  # Get PHQ-A responses
  #
  # @return [Array<Hash>] PHQ-A item responses
  def phq_a_responses
    parsed_responses[:phq_a] || []
  end

  # Get GAD-7 responses
  #
  # @return [Array<Hash>] GAD-7 item responses
  def gad_7_responses
    parsed_responses[:gad_7] || []
  end

  # Get PHQ-A total score
  #
  # @return [Integer, nil] Total PHQ-A score (0-27)
  def phq_a_score
    parsed_responses.dig(:scores, :phq_a_total)
  end

  # Get GAD-7 total score
  #
  # @return [Integer, nil] Total GAD-7 score (0-21)
  def gad_7_score
    parsed_responses.dig(:scores, :gad_7_total)
  end

  # Get current progress
  #
  # @return [Hash] Progress with current instrument and next question
  def progress
    parsed_responses[:progress] || {}
  end

  # Check if PHQ-A is complete
  #
  # @return [Boolean] True if all 9 PHQ-A questions answered
  def phq_a_complete?
    phq_a_responses.length == 9
  end

  # Check if GAD-7 is complete
  #
  # @return [Boolean] True if all 7 GAD-7 questions answered
  def gad_7_complete?
    gad_7_responses.length == 7
  end

  # Check if assessment is complete
  #
  # @return [Boolean] True if both instruments complete
  def assessment_complete?
    phq_a_complete? && gad_7_complete?
  end

  # Get count of completed questions
  #
  # @return [Integer] Total completed questions (max 16)
  def completed_questions_count
    phq_a_responses.length + gad_7_responses.length
  end

  # Get total questions count
  #
  # @return [Integer] Total questions (16)
  def total_questions_count
    16 # 9 PHQ-A + 7 GAD-7
  end

  # Get progress percentage
  #
  # @return [Integer] Progress percentage (0-100)
  def progress_percentage
    ((completed_questions_count.to_f / total_questions_count) * 100).round
  end

  # Add response to assessment
  # FR26: Validates response value (0-3) and stores with metadata
  #
  # @param instrument [String] Instrument name ('phq_a' or 'gad_7')
  # @param item [Integer] Question item number (1-based)
  # @param value [Integer] Likert scale value (0-3)
  # @param raw_text [String] Original natural language response
  # @param question_text [String] The question that was asked
  # @return [Boolean] True if response added successfully
  def add_response(instrument:, item:, value:, raw_text:, question_text:)
    # Validate value is in range
    unless value.between?(0, 3)
      errors.add(:base, "Response value must be between 0 and 3")
      return false
    end

    # Validate raw_text length (FR26)
    if raw_text.blank? || raw_text.length > 500
      errors.add(:base, "Response text must be 1-500 characters")
      return false
    end

    # Get current responses
    current = parsed_responses

    # Initialize instrument array if needed
    current[instrument.to_sym] ||= []

    # Check for duplicate
    existing = current[instrument.to_sym].find { |r| r[:item] == item }
    if existing
      errors.add(:base, "Question already answered")
      return false
    end

    # Add response
    current[instrument.to_sym] << {
      item: item,
      question: question_text,
      value: value,
      raw_text: raw_text,
      timestamp: Time.current.iso8601
    }

    # Update progress
    update_progress(current, instrument)

    # Recalculate scores
    recalculate_scores(current)

    # Store updated responses
    self.responses = current.to_json
    true
  end

  private

  # Validate status transitions
  # Story 5.1: State transitions must follow: nil/not_started -> in_progress -> complete
  def valid_status_transition
    old_status = status_was
    new_status = status

    valid_transitions = {
      'not_started' => %w[in_progress],
      'in_progress' => %w[complete],
      'complete' => [] # Cannot transition from complete
    }

    unless valid_transitions[old_status]&.include?(new_status)
      errors.add(:status, "cannot transition from #{old_status} to #{new_status}")
    end
  end

  # Update progress tracking
  def update_progress(responses, instrument)
    responses[:progress] ||= {}

    if instrument.to_s == 'phq_a'
      phq_a_count = responses[:phq_a]&.length || 0
      responses[:progress][:phq_a_complete] = phq_a_count == 9
      if phq_a_count < 9
        responses[:progress][:current_instrument] = 'phq_a'
        responses[:progress][:next_question_id] = "phq_a_#{phq_a_count + 1}"
      elsif (responses[:gad_7]&.length || 0) < 7
        responses[:progress][:current_instrument] = 'gad_7'
        responses[:progress][:next_question_id] = "gad_7_1"
      end
    end

    if instrument.to_s == 'gad_7'
      gad_7_count = responses[:gad_7]&.length || 0
      responses[:progress][:gad_7_complete] = gad_7_count == 7
      if gad_7_count < 7
        responses[:progress][:current_instrument] = 'gad_7'
        responses[:progress][:next_question_id] = "gad_7_#{gad_7_count + 1}"
      else
        responses[:progress][:next_question_id] = nil
      end
    end
  end

  # Recalculate instrument scores
  def recalculate_scores(responses)
    responses[:scores] ||= {}

    # PHQ-A total (0-27)
    if responses[:phq_a]&.any?
      responses[:scores][:phq_a_total] = responses[:phq_a].sum { |r| r[:value] || 0 }
    end

    # GAD-7 total (0-21)
    if responses[:gad_7]&.any?
      responses[:scores][:gad_7_total] = responses[:gad_7].sum { |r| r[:value] || 0 }
    end

    # Combined score (0-100 normalized)
    phq_total = responses[:scores][:phq_a_total] || 0
    gad_total = responses[:scores][:gad_7_total] || 0
    max_combined = 48 # 27 + 21
    if phq_total > 0 || gad_total > 0
      self.score = (((phq_total + gad_total).to_f / max_combined) * 100).round
    end
  end
end
