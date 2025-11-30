# frozen_string_literal: true

module Ai
  # Service to detect when a parent is requesting human assistance
  # AC 3.5.8: AI detects escalation intent from specific phrases
  #
  # Usage:
  #   detector = Ai::EscalationDetector.new
  #   result = detector.detect_escalation_intent("I want to talk to a real person")
  #   => { escalation_detected: true, matched_phrases: ["talk to.*real person"] }
  class EscalationDetector
    # Escalation trigger phrases (case-insensitive)
    # AC 3.5.8: Phrases that indicate desire to speak with human
    ESCALATION_PHRASES = [
      'speak to human',
      'talk to person',
      'real person',
      'not a bot',
      'representative',
      'actual person',
      'human help',
      'speak to someone',
      'talk to someone',
      'speak with someone',
      'talk to a human',
      'speak to a human',
      'talk to real',
      'speak to real',
      'live person',
      'actual human',
      'customer service',
      'talk to support',
      'speak to support'
    ].freeze

    # Detect if message contains escalation intent
    # AC 3.5.8: Case-insensitive phrase matching
    #
    # @param message_text [String] The message to analyze
    # @return [Hash] Result with escalation_detected boolean and matched_phrases array
    def detect_escalation_intent(message_text)
      return { escalation_detected: false, matched_phrases: [] } if message_text.blank?

      # Normalize message for matching
      normalized_message = message_text.downcase.strip

      # Find all matching phrases
      matched = ESCALATION_PHRASES.select do |phrase|
        # Use regex to match phrase with word boundaries for more flexible matching
        # This allows "I want to talk to a real person" to match "talk to.*real person"
        pattern = phrase.split.map { |word| Regexp.escape(word) }.join('.*')
        normalized_message.match?(/#{pattern}/)
      end

      {
        escalation_detected: matched.any?,
        matched_phrases: matched
      }
    end

    # Check if escalation was detected (convenience method)
    # @param message_text [String] The message to analyze
    # @return [Boolean] True if escalation intent detected
    def escalation_detected?(message_text)
      detect_escalation_intent(message_text)[:escalation_detected]
    end
  end
end
