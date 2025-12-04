# frozen_string_literal: true

module Queries
  # GraphQL query resolver for dynamic quick reply suggestions
  # Returns AI-generated contextual response options for the chat interface
  #
  # Suggestions are only generated during appropriate conversation phases
  # (concerns, assessment) and not during data collection (welcome, parent_info, child_info).
  #
  # This is a non-critical feature - returns empty array on any error.
  class SuggestedReplies < GraphQL::Schema::Resolver
    include GraphqlConcerns::CurrentSession

    description "Get AI-generated quick reply suggestions based on conversation context"

    # Arguments
    argument :session_id, ID, required: true,
             description: "Onboarding session ID"
    argument :message_id, ID, required: false,
             description: "Optional message ID to base suggestions on (defaults to latest)"

    # Return type
    type [Types::QuickReplyOptionType], null: false

    # Generate contextual suggestions
    #
    # @param session_id [String] Session UUID
    # @param message_id [String, nil] Optional message ID
    # @return [Array<Hash>] Quick reply suggestions
    def resolve(session_id:, message_id: nil)
      # Load and authorize session
      session = load_session(session_id)
      authorize_session!(session)

      # Generate suggestions
      generator = Ai::SuggestionGenerator.new(session_id: session.id)
      suggestions = generator.generate(last_message_id: message_id)

      # Convert to expected format
      suggestions.map do |suggestion|
        OpenStruct.new(
          label: suggestion[:label],
          value: suggestion[:value],
          icon: suggestion[:icon]
        )
      end
    rescue ActiveRecord::RecordNotFound
      # Non-critical - return empty on not found
      Rails.logger.warn("SuggestedReplies: Session not found: #{session_id}")
      []
    rescue GraphQL::ExecutionError
      # Re-raise GraphQL errors (like auth errors)
      raise
    rescue StandardError => e
      # Non-critical feature - return empty on any other error
      Rails.logger.warn("SuggestedReplies error: #{e.message}")
      []
    end

    private

    # Load session by ID
    #
    # @param session_id [String] Session ID (with or without sess_ prefix)
    # @return [OnboardingSession] Session record
    def load_session(session_id)
      actual_id = normalize_session_id(session_id)
      OnboardingSession.find(actual_id)
    end

    # Verify user has access to this session
    #
    # @param session [OnboardingSession] Session to authorize
    # @raise [GraphQL::ExecutionError] If unauthorized
    def authorize_session!(session)
      unless current_session && current_session.id == session.id
        raise GraphQL::ExecutionError.new(
          'Access denied',
          extensions: {
            code: 'UNAUTHENTICATED',
            timestamp: Time.current.iso8601
          }
        )
      end
    end
  end
end
