# frozen_string_literal: true

module Assessments
  # Response Parser for natural language Likert responses
  # Story 5.1: Conversational Screening Questions
  #
  # Parses natural language responses from parents and maps them
  # to standardized Likert scale values (0-3).
  #
  # FR26 Validation:
  # - Response value must be 0-3
  # - Response text must be 1-500 characters
  class ResponseParser
    # Likert value keywords for fuzzy matching
    # Order matters - more specific phrases first
    LIKERT_PATTERNS = {
      3 => [
        /nearly every day/i,
        /almost every day/i,
        /every day/i,
        /every single day/i,
        /all the time/i,
        /constantly/i,
        /always/i,
        /daily/i,
        /all day/i,
        /non-?stop/i
      ],
      2 => [
        /more than half/i,
        /most days/i,
        /most of the time/i,
        /often/i,
        /frequently/i,
        /pretty often/i,
        /quite a bit/i,
        /a lot/i,
        /regularly/i,
        /usually/i,
        /much of the time/i
      ],
      1 => [
        /several days/i,
        /some days/i,
        /sometimes/i,
        /occasionally/i,
        /a few days/i,
        /once in a while/i,
        /now and then/i,
        /from time to time/i,
        /here and there/i,
        /a little/i,
        /a bit/i,
        /somewhat/i
      ],
      0 => [
        /not at all/i,
        /not really/i,
        /never/i,
        /none/i,
        /rarely/i,
        /hardly ever/i,
        /almost never/i,
        /no$/i,
        /^no[,\.\s]/i,
        /nope/i,
        /not much/i,
        /doesn't seem/i,
        /hasn't been/i,
        /haven't noticed/i
      ]
    }.freeze

    # Ambiguous phrases that need clarification
    AMBIGUOUS_PATTERNS = [
      /not sure/i,
      /don't know/i,
      /i think/i,
      /maybe/i,
      /kind of/i,
      /sort of/i,
      /hard to say/i,
      /it varies/i,
      /depends/i,
      /uncertain/i,
      /can't really tell/i,
      /it's complicated/i
    ].freeze

    class << self
      # Parse natural language response to Likert value
      #
      # @param response_text [String] Natural language response
      # @return [Hash] Result with value, confidence, and ambiguity flag
      def parse(response_text)
        return { value: nil, confidence: :none, ambiguous: true, error: 'Empty response' } if response_text.blank?

        normalized = normalize_text(response_text)

        # Check for ambiguous responses first
        if ambiguous_response?(normalized)
          return {
            value: nil,
            confidence: :none,
            ambiguous: true,
            needs_clarification: true,
            suggestion: generate_clarification_prompt
          }
        end

        # Try to match Likert patterns
        result = match_likert_value(normalized)

        if result[:value].nil?
          # Fall back to keyword analysis
          result = analyze_keywords(normalized)
        end

        result
      end

      # Parse with AI assistance for complex responses
      # Uses AI to interpret ambiguous or complex responses
      #
      # @param response_text [String] Natural language response
      # @param ai_client [Ai::Client] AI client for interpretation
      # @return [Hash] Parsed result
      def parse_with_ai(response_text, ai_client:)
        # First try rule-based parsing
        result = parse(response_text)
        return result if result[:confidence] == :high

        # Use AI for ambiguous or low-confidence responses
        ai_result = ai_interpret(response_text, ai_client)
        return ai_result if ai_result[:confidence] == :high

        # Return best guess with low confidence flag
        result[:needs_clarification] = true
        result
      end

      # Validate response text meets FR26 requirements
      #
      # @param response_text [String] Response text to validate
      # @return [Hash] Validation result
      def validate(response_text)
        errors = []

        if response_text.blank?
          errors << 'Response text is required'
        elsif response_text.length > 500
          errors << 'Response text must be 500 characters or less'
        end

        { valid: errors.empty?, errors: errors }
      end

      private

      # Normalize text for matching
      def normalize_text(text)
        text.to_s.strip.downcase.gsub(/[^\w\s]/, ' ').gsub(/\s+/, ' ')
      end

      # Check if response is ambiguous
      def ambiguous_response?(text)
        AMBIGUOUS_PATTERNS.any? { |pattern| text.match?(pattern) }
      end

      # Match text against Likert patterns
      def match_likert_value(text)
        # Check patterns in order of specificity (3 -> 0)
        [3, 2, 1, 0].each do |value|
          patterns = LIKERT_PATTERNS[value]
          if patterns.any? { |pattern| text.match?(pattern) }
            return {
              value: value,
              confidence: :high,
              ambiguous: false,
              matched_pattern: true
            }
          end
        end

        { value: nil, confidence: :none, ambiguous: false, matched_pattern: false }
      end

      # Analyze keywords for sentiment/frequency
      def analyze_keywords(text)
        # Count positive vs negative frequency indicators
        high_freq_words = %w[every always constantly daily often usually most]
        mid_freq_words = %w[sometimes occasionally few bit]
        low_freq_words = %w[rarely hardly never none not]

        high_count = high_freq_words.count { |w| text.include?(w) }
        mid_count = mid_freq_words.count { |w| text.include?(w) }
        low_count = low_freq_words.count { |w| text.include?(w) }

        if low_count > high_count && low_count > mid_count
          { value: 0, confidence: :medium, ambiguous: false }
        elsif high_count > mid_count && high_count > low_count
          { value: text.include?('every') ? 3 : 2, confidence: :medium, ambiguous: false }
        elsif mid_count > 0
          { value: 1, confidence: :medium, ambiguous: false }
        else
          { value: nil, confidence: :low, ambiguous: true, needs_clarification: true }
        end
      end

      # Use AI to interpret response
      def ai_interpret(response_text, ai_client)
        prompt = <<~PROMPT
          You are helping parse a parent's response to a mental health screening question.
          The response should be mapped to a Likert scale:
          - 0 = Not at all
          - 1 = Several days (out of the past 2 weeks)
          - 2 = More than half the days
          - 3 = Nearly every day

          Parent's response: "#{response_text}"

          Respond with ONLY a single digit (0, 1, 2, or 3) representing the Likert value.
          If the response cannot be mapped, respond with "unclear".
        PROMPT

        begin
          response = ai_client.chat(
            messages: [{ role: 'user', content: prompt }],
            context: { purpose: 'likert_parsing' }
          )

          value = response[:content].to_s.strip.to_i
          if value.between?(0, 3)
            { value: value, confidence: :high, ambiguous: false, ai_assisted: true }
          else
            { value: nil, confidence: :low, ambiguous: true, ai_assisted: true }
          end
        rescue StandardError => e
          Rails.logger.error("AI interpretation error: #{e.message}")
          { value: nil, confidence: :none, ambiguous: true, error: 'AI interpretation failed' }
        end
      end

      # Generate clarification prompt
      def generate_clarification_prompt
        "I want to make sure I understand correctly. In the past two weeks, " \
          "would you say this happened not at all, several days, more than half the days, " \
          "or nearly every day?"
      end
    end
  end
end
