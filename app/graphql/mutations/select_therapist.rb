# frozen_string_literal: true

module Mutations
  # GraphQL mutation for recording parent's therapist selection
  # Updates TherapistMatch record for analytics
  #
  # Story 5.4: Matching Recommendations API
  class SelectTherapist < BaseMutation
    include GraphqlConcerns::CurrentSession

    description "Record parent's therapist selection for analytics"

    # Arguments
    argument :session_id, ID, required: true,
             description: "Onboarding session ID"

    argument :therapist_id, ID, required: true,
             description: "Selected therapist ID"

    # Return type
    field :therapist_match, Types::TherapistMatchType, null: true,
          description: "Updated match record with selection"

    field :success, Boolean, null: false,
          description: "Whether selection was recorded successfully"

    field :errors, [String], null: false,
          description: "Any error messages"

    # Record therapist selection
    #
    # @param session_id [String] Session UUID
    # @param therapist_id [String] Therapist UUID
    # @return [Hash] Result with success and match
    def resolve(session_id:, therapist_id:)
      # Load and authorize session
      session = load_session(session_id)
      authorize_session!(session)

      # Verify therapist exists
      therapist = load_therapist(therapist_id)

      # Find most recent match for this session
      match = TherapistMatch.where(onboarding_session_id: session.id)
                           .order(created_at: :desc)
                           .first

      unless match
        return {
          success: false,
          therapist_match: nil,
          errors: ["No matching results found for this session"]
        }
      end

      # Update match with selected therapist
      if match.mark_selected(therapist.id)
        {
          success: true,
          therapist_match: match,
          errors: []
        }
      else
        {
          success: false,
          therapist_match: nil,
          errors: match.errors.full_messages
        }
      end
    rescue GraphQL::ExecutionError => e
      # Re-raise GraphQL errors
      raise e
    rescue StandardError => e
      Rails.logger.error("Error selecting therapist: #{e.message}\n#{e.backtrace.join("\n")}")
      {
        success: false,
        therapist_match: nil,
        errors: ["An unexpected error occurred"]
      }
    end

    private

    # Load session by ID
    #
    # @param session_id [String] Session ID
    # @return [OnboardingSession] Session record
    # @raise [GraphQL::ExecutionError] If session not found
    def load_session(session_id)
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

    # Load therapist by ID
    #
    # @param therapist_id [String] Therapist UUID
    # @return [Therapist] Therapist record
    # @raise [GraphQL::ExecutionError] If therapist not found
    def load_therapist(therapist_id)
      Therapist.find(therapist_id)
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError.new(
        'Therapist not found',
        extensions: {
          code: 'NOT_FOUND',
          timestamp: Time.current.iso8601
        }
      )
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
