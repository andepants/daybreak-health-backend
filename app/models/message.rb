# frozen_string_literal: true

class Message < ApplicationRecord
  include Encryptable

  # Enums
  enum :role, {
    user: 0,
    assistant: 1,
    system: 2
  }

  # Associations
  belongs_to :onboarding_session

  # PHI Encryption
  encrypts_phi :content

  # Validations
  validates :role, presence: true
  validates :content, presence: true
  validates :onboarding_session, presence: true

  # Story 3.3: Intent tracking methods

  # Store intent classification result in metadata
  #
  # @param intent_result [Hash] Result from Ai::IntentClassifier
  def store_intent(intent_result)
    self.metadata ||= {}
    self.metadata['intent'] = intent_result[:intent].to_s
    self.metadata['intent_confidence'] = intent_result[:confidence]
    self.metadata['intent_pattern'] = intent_result[:pattern]
    self.metadata['intent_method'] = intent_result[:detected_method]
    self.metadata['classified_at'] = Time.current.iso8601
  end

  # Get stored intent
  #
  # @return [String, nil] Intent type
  def intent
    metadata&.dig('intent')
  end

  # Get intent confidence
  #
  # @return [Float, nil] Confidence score
  def intent_confidence
    metadata&.dig('intent_confidence')
  end

  # Check if message was classified as help request
  #
  # @return [Boolean] True if help request
  def help_request?
    intent.to_s == 'help_request'
  end

  # Check if message was classified as off-topic
  #
  # @return [Boolean] True if off-topic
  def off_topic?
    intent.to_s == 'off_topic'
  end

  # Check if message was classified as question
  #
  # @return [Boolean] True if question
  def question?
    intent.to_s == 'question'
  end
end
