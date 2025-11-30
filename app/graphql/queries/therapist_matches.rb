# frozen_string_literal: true

module Queries
  # GraphQL query resolver for therapist matching recommendations
  # Returns AI-matched therapists with scores, reasoning, and availability
  #
  # Story 5.4: Matching Recommendations API
  # AC1, AC10, AC13: Query returns personalized matches for session
  class TherapistMatches < GraphQL::Schema::Resolver
    include GraphqlConcerns::CurrentSession

    description "Get AI-matched therapist recommendations for a session"

    # Arguments
    argument :session_id, ID, required: true,
             description: "Onboarding session ID"

    # Return type
    type [Types::TherapistMatchResultType], null: false

    # AC1: Execute matching query
    #
    # @param session_id [String] Session UUID
    # @return [Array<TherapistMatchResult>] Matched therapists
    # @raise [GraphQL::ExecutionError] If unauthorized or session incomplete
    def resolve(session_id:)
      # Load and authorize session
      session = load_session(session_id)
      authorize_session!(session)
      validate_session_ready!(session)

      # Execute matching service
      matching_service = Scheduling::MatchingService.new(session_id: session.id)
      matches = matching_service.match

      # AC13: Return at least 3 matches when possible
      matches
    rescue ArgumentError => e
      raise GraphQL::ExecutionError.new(
        e.message,
        extensions: {
          code: 'VALIDATION_ERROR',
          timestamp: Time.current.iso8601
        }
      )
    end

    private

    # Load session by ID
    #
    # @param session_id [String] Session ID (with or without sess_ prefix)
    # @return [OnboardingSession] Session record
    # @raise [GraphQL::ExecutionError] If session not found
    def load_session(session_id)
      # Strip sess_ prefix and convert to UUID if needed
      actual_id = normalize_session_id(session_id)

      OnboardingSession.find(actual_id)
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError.new(
        'Session not found',
        extensions: {
          code: 'NOT_FOUND',
          timestamp: Time.current.iso8601
        }
      )
    end

    # AC1: Verify user has access to this session
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

    # AC1: Validate session is ready for matching
    # Session must have child, insurance, and complete assessment
    #
    # @param session [OnboardingSession] Session to validate
    # @raise [GraphQL::ExecutionError] If session incomplete
    def validate_session_ready!(session)
      unless session.child
        raise GraphQL::ExecutionError.new(
          'Session must have child information',
          extensions: {
            code: 'VALIDATION_ERROR',
            timestamp: Time.current.iso8601
          }
        )
      end

      unless session.insurance
        raise GraphQL::ExecutionError.new(
          'Session must have insurance information',
          extensions: {
            code: 'VALIDATION_ERROR',
            timestamp: Time.current.iso8601
          }
        )
      end

      unless session.assessment&.status == "complete"
        raise GraphQL::ExecutionError.new(
          'Assessment must be complete to request therapist matches',
          extensions: {
            code: 'VALIDATION_ERROR',
            timestamp: Time.current.iso8601
          }
        )
      end
    end
  end
end
