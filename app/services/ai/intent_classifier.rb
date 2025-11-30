# frozen_string_literal: true

module Ai
  # Intent Classifier Service (Story 3.3)
  # Classifies user message intent to distinguish between answers, questions,
  # help requests, off-topic responses, and clarification requests.
  #
  # Acceptance Criteria:
  # - AC1: Recognizes question vs. answer intent
  # - AC6: Handles various help intent patterns
  #
  # Strategy:
  # 1. Fast keyword-based classification for obvious patterns
  # 2. LLM-based classification as fallback for ambiguous cases
  # 3. Confidence scoring to determine reliability
  #
  # Usage:
  #   result = Ai::IntentClassifier.call(
  #     message: "I don't understand what you're asking",
  #     context: { current_phase: "parent_info", last_question: "What's your email?" }
  #   )
  #   # => { intent: :help_request, confidence: 0.95, pattern: "i don't understand" }
  class IntentClassifier < BaseService
    # Intent types
    INTENTS = %i[
      answer
      question
      help_request
      off_topic
      clarification
    ].freeze

    # Keywords that strongly indicate help requests
    HELP_KEYWORDS = [
      "i don't understand",
      "i don't get it",
      "what does",
      "what is",
      "what do you mean",
      "why are you asking",
      "why do you need",
      "why is this needed",
      "help",
      "confused",
      "unclear",
      "don't know what you mean",
      "what are you asking"
    ].freeze

    # Keywords that indicate clarification questions
    CLARIFICATION_KEYWORDS = [
      "can you explain",
      "could you clarify",
      "what exactly",
      "which",
      "do you mean",
      "are you asking",
      "is this about"
    ].freeze

    # Keywords that indicate off-topic responses
    OFF_TOPIC_KEYWORDS = [
      "how much does this cost",
      "what are your hours",
      "where are you located",
      "how long will this take",
      "when will i hear back",
      "can i talk to someone"
    ].freeze

    # Patterns for off-topic detection (checked before generic questions)
    OFF_TOPIC_PATTERNS = [
      { pattern: /how much.*(?:cost|pay|price|afford|charge)/i, topic: 'cost' },
      { pattern: /what.*(?:hours|time|schedule|open|available)/i, topic: 'hours' },
      { pattern: /where.*(?:located|address|find you)/i, topic: 'location' },
      { pattern: /how long.*take/i, topic: 'timeline' },
      { pattern: /when.*(?:hear back|get response|contact|call)/i, topic: 'timeline' }
    ].freeze

    # Question indicators
    QUESTION_INDICATORS = [
      "?",
      "what",
      "why",
      "how",
      "when",
      "where",
      "who",
      "can you",
      "could you",
      "will you"
    ].freeze

    # Confidence thresholds
    HIGH_CONFIDENCE = 0.8
    MEDIUM_CONFIDENCE = 0.5

    def initialize(message:, context: {})
      @message = message.to_s.strip
      @context = context
      @normalized_message = @message.downcase
    end

    def call
      # Return early if message is empty
      return default_result(:answer, 0.0, "empty_message") if @message.blank?

      # Try keyword-based classification first (fast path)
      keyword_result = keyword_classification
      return keyword_result if keyword_result[:confidence] >= HIGH_CONFIDENCE

      # Fall back to LLM classification for ambiguous cases
      # For MVP, we'll use enhanced heuristics
      # In production, this would call LLM with structured prompt
      enhanced_classification
    end

    private

    # Keyword-based intent classification
    # Fast, rule-based detection for obvious patterns
    #
    # @return [Hash] Classification result with intent, confidence, pattern
    def keyword_classification
      # Check for help request patterns
      HELP_KEYWORDS.each do |keyword|
        if @normalized_message.include?(keyword)
          return {
            intent: :help_request,
            confidence: 0.95,
            pattern: keyword,
            detected_method: "keyword"
          }
        end
      end

      # Check for clarification patterns
      CLARIFICATION_KEYWORDS.each do |keyword|
        if @normalized_message.include?(keyword)
          return {
            intent: :clarification,
            confidence: 0.90,
            pattern: keyword,
            detected_method: "keyword"
          }
        end
      end

      # Check for off-topic patterns (exact keywords first)
      OFF_TOPIC_KEYWORDS.each do |keyword|
        if @normalized_message.include?(keyword)
          return {
            intent: :off_topic,
            confidence: 0.85,
            pattern: keyword,
            detected_method: "keyword"
          }
        end
      end

      # Check for off-topic regex patterns (before generic questions)
      OFF_TOPIC_PATTERNS.each do |pattern_config|
        if @message.match?(pattern_config[:pattern])
          return {
            intent: :off_topic,
            confidence: 0.82,
            pattern: pattern_config[:topic],
            detected_method: "pattern"
          }
        end
      end

      # Check for question indicators
      if question_pattern?
        return {
          intent: :question,
          confidence: 0.80,
          pattern: "question_indicator",
          detected_method: "keyword"
        }
      end

      # Default to medium confidence answer
      {
        intent: :answer,
        confidence: 0.60,
        pattern: "default",
        detected_method: "keyword"
      }
    end

    # Enhanced heuristic classification
    # Uses multiple signals to improve accuracy when keywords are ambiguous
    #
    # @return [Hash] Classification result with intent, confidence, pattern
    def enhanced_classification
      signals = {
        has_question_mark: @message.include?("?"),
        has_question_words: question_words_present?,
        is_very_short: @message.length < 10,
        is_very_long: @message.length > 200,
        has_uncertainty: uncertainty_present?,
        has_personal_info: personal_info_pattern?,
        context_suggests_answer: context_suggests_answer?
      }

      # Help request heuristics
      if signals[:has_uncertainty] && (signals[:has_question_mark] || signals[:is_very_short])
        return {
          intent: :help_request,
          confidence: 0.75,
          pattern: "uncertainty_with_question",
          detected_method: "heuristic",
          signals: signals
        }
      end

      # Question heuristics
      if signals[:has_question_mark] && signals[:has_question_words]
        return {
          intent: :question,
          confidence: 0.85,
          pattern: "question_mark_with_words",
          detected_method: "heuristic",
          signals: signals
        }
      end

      # Off-topic heuristics (very long responses often go off-topic)
      if signals[:is_very_long] && !signals[:has_personal_info]
        return {
          intent: :off_topic,
          confidence: 0.65,
          pattern: "long_without_personal_info",
          detected_method: "heuristic",
          signals: signals
        }
      end

      # Answer heuristics
      if signals[:has_personal_info] || signals[:context_suggests_answer]
        return {
          intent: :answer,
          confidence: 0.80,
          pattern: "personal_info_or_context",
          detected_method: "heuristic",
          signals: signals
        }
      end

      # Default to answer with low confidence
      {
        intent: :answer,
        confidence: 0.50,
        pattern: "default_fallback",
        detected_method: "heuristic",
        signals: signals
      }
    end

    # Check if message contains question patterns
    #
    # @return [Boolean] True if question pattern detected
    def question_pattern?
      return true if @message.include?("?")

      QUESTION_INDICATORS.any? do |indicator|
        @normalized_message.start_with?(indicator) ||
          @normalized_message.include?(" #{indicator} ")
      end
    end

    # Check if message contains question words
    #
    # @return [Boolean] True if question words present
    def question_words_present?
      question_words = %w[what why how when where who which]
      question_words.any? { |word| @normalized_message.include?(word) }
    end

    # Check if message contains uncertainty markers
    #
    # @return [Boolean] True if uncertainty detected
    def uncertainty_present?
      uncertainty_markers = [
        "not sure",
        "don't know",
        "don't remember",
        "maybe",
        "i think",
        "probably",
        "unsure",
        "uncertain"
      ]

      uncertainty_markers.any? { |marker| @normalized_message.include?(marker) }
    end

    # Check if message contains personal information patterns
    # This helps identify answers to intake questions
    #
    # @return [Boolean] True if personal info detected
    def personal_info_pattern?
      # Email pattern
      return true if @message.match?(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/)

      # Phone pattern
      return true if @message.match?(/\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/)

      # Name patterns (capitalized words)
      return true if @message.match?(/\b[A-Z][a-z]+\s+[A-Z][a-z]+\b/)

      # Age/number patterns
      return true if @message.match?(/\b\d{1,2}\s*(years?|months?|old)\b/i)

      # Date patterns
      return true if @message.match?(/\b\d{1,2}\/\d{1,2}\/\d{2,4}\b/)

      false
    end

    # Check if context suggests this should be an answer
    # Uses conversation context to improve classification
    #
    # @return [Boolean] True if context suggests answer
    def context_suggests_answer?
      return false if @context.blank?

      # If we just asked a specific question, response is likely an answer
      return true if @context[:last_question].present?

      # If we're collecting specific info in a phase, likely an answer
      return true if @context[:collecting_field].present?

      # If we have missing required fields, responses are likely answers
      return true if @context[:missing_fields].present? && @context[:missing_fields].any?

      false
    end

    # Default result for edge cases
    #
    # @param intent [Symbol] Intent type
    # @param confidence [Float] Confidence score
    # @param pattern [String] Pattern detected
    # @return [Hash] Default result
    def default_result(intent, confidence, pattern)
      {
        intent: intent,
        confidence: confidence,
        pattern: pattern,
        detected_method: "default"
      }
    end
  end
end
