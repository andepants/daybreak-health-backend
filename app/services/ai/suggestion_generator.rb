# frozen_string_literal: true

module Ai
  # Generates dynamic quick reply suggestions based on conversation context
  #
  # Uses the AI to generate 2-4 contextual response suggestions that appear
  # as clickable pillboxes in the chat interface. Only generates suggestions
  # during appropriate conversation phases (concerns, not during data collection).
  #
  # Usage:
  #   generator = Ai::SuggestionGenerator.new(session_id: session.id)
  #   suggestions = generator.generate(last_message_id: message.id)
  #   # => [{ label: "Tell me more", value: "Tell me more" }, ...]
  class SuggestionGenerator
    # Phases where suggestions should be shown (open-ended conversation)
    ELIGIBLE_PHASES = %w[concerns].freeze

    # Phases where suggestions should NOT be shown (data collection/validation)
    INELIGIBLE_PHASES = %w[welcome parent_info child_info].freeze

    # Maximum tokens for suggestion generation (keep it fast)
    MAX_TOKENS = 150

    # Initialize suggestion generator for a session
    #
    # @param session_id [String] UUID of the onboarding session
    def initialize(session_id:)
      @session_id = session_id
      @session = OnboardingSession.find(session_id)
      @context_manager = ContextManager.new(session_id: session_id)
    end

    # Generate contextual suggestions based on the last AI message
    #
    # @param last_message_id [String, nil] Optional ID of the last message for context
    # @return [Array<Hash>] Array of suggestion hashes with :label, :value, and optional :icon
    def generate(last_message_id: nil)
      return [] unless eligible_for_suggestions?

      last_message = fetch_last_ai_message(last_message_id)
      return [] if last_message.nil?

      generate_suggestions(last_message)
    rescue StandardError => e
      Rails.logger.warn("SuggestionGenerator error: #{e.message}")
      [] # Non-critical feature - return empty on any error
    end

    # Check if current conversation phase allows suggestions
    #
    # @return [Boolean] True if suggestions should be generated
    def eligible_for_suggestions?
      current_phase = @context_manager.current_phase

      # Explicitly check eligibility
      return true if ELIGIBLE_PHASES.include?(current_phase)

      # Also allow during assessment mode if session has assessment
      return true if @session.assessment.present? && @session.assessment.status != 'complete'

      false
    end

    private

    # Fetch the last AI message from the conversation
    #
    # @param message_id [String, nil] Specific message ID or nil for latest
    # @return [Message, nil] The last AI message or nil
    def fetch_last_ai_message(message_id)
      if message_id.present?
        Message.find_by(id: message_id, onboarding_session_id: @session_id, role: :assistant)
      else
        Message.where(onboarding_session_id: @session_id, role: :assistant)
               .order(created_at: :desc)
               .first
      end
    end

    # Generate suggestions using AI based on the last message
    #
    # @param last_message [Message] The AI message to base suggestions on
    # @return [Array<Hash>] Generated suggestions
    def generate_suggestions(last_message)
      messages = build_suggestion_prompt(last_message)

      client = Client.new
      response = client.chat(
        messages: messages,
        context: { max_tokens: MAX_TOKENS, temperature: 0.7 }
      )

      parse_suggestions(response[:content])
    rescue StandardError => e
      Rails.logger.warn("Failed to generate suggestions: #{e.message}")
      fallback_suggestions(last_message)
    end

    # Build the prompt for suggestion generation
    #
    # @param last_message [Message] The AI message to base suggestions on
    # @return [Array<Hash>] Messages array for AI call
    def build_suggestion_prompt(last_message)
      # Get recent conversation context (last 3 exchanges)
      recent_messages = Message.where(onboarding_session_id: @session_id)
                               .order(created_at: :desc)
                               .limit(6)
                               .reverse
                               .map { |m| "#{m.role.upcase}: #{m.content}" }
                               .join("\n")

      system_prompt = <<~PROMPT
        You are helping generate quick reply suggestions for a parent intake chat.
        Based on the AI assistant's last message, generate 2-4 brief, natural response options
        that a parent might want to click instead of typing.

        Rules:
        - Keep each suggestion under 40 characters
        - Make them feel natural and conversational
        - Vary the types: one could be a question, one an affirmation, one asking for more info
        - Don't include options that collect specific data (like names or dates)
        - Focus on open-ended engagement

        Return ONLY a JSON array of strings, nothing else. Example:
        ["Tell me more about that", "Yes, I've noticed this too", "What should I expect?"]
      PROMPT

      [
        { role: 'system', content: system_prompt },
        { role: 'user', content: "Recent conversation:\n#{recent_messages}\n\nGenerate 2-4 quick reply suggestions based on the assistant's last message." }
      ]
    end

    # Parse AI response into suggestion objects
    #
    # @param content [String] AI response content
    # @return [Array<Hash>] Parsed suggestions
    def parse_suggestions(content)
      # Try to parse as JSON array
      suggestions = JSON.parse(content)

      unless suggestions.is_a?(Array)
        Rails.logger.warn("Suggestions not an array: #{content}")
        return []
      end

      # Convert strings to suggestion hashes, limit to 4
      suggestions.take(4).map do |suggestion|
        text = suggestion.is_a?(String) ? suggestion : suggestion.to_s
        {
          label: text.truncate(50),
          value: text.truncate(50)
        }
      end
    rescue JSON::ParserError => e
      Rails.logger.warn("Failed to parse suggestions JSON: #{e.message}")
      # Try to extract suggestions from text response
      extract_suggestions_from_text(content)
    end

    # Extract suggestions from non-JSON text response
    #
    # @param content [String] Text content that might contain suggestions
    # @return [Array<Hash>] Extracted suggestions
    def extract_suggestions_from_text(content)
      # Try to find quoted strings
      quotes = content.scan(/"([^"]+)"/).flatten

      return quotes.take(4).map { |q| { label: q, value: q } } if quotes.any?

      # Fall back to numbered list extraction
      lines = content.split(/\n/).map(&:strip).reject(&:empty?)
      numbered = lines.select { |l| l.match?(/^\d+[\.\)]\s*/) }

      return numbered.take(4).map { |l| text = l.sub(/^\d+[\.\)]\s*/, ''); { label: text, value: text } } if numbered.any?

      []
    end

    # Fallback suggestions when AI generation fails
    #
    # @param last_message [Message] The AI message for context
    # @return [Array<Hash>] Static fallback suggestions
    def fallback_suggestions(_last_message)
      [
        { label: 'Tell me more', value: 'Tell me more' },
        { label: "Yes, that's right", value: "Yes, that's right" },
        { label: 'I have a question', value: 'I have a question' }
      ]
    end
  end
end
