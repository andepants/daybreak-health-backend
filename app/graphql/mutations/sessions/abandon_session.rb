# frozen_string_literal: true

module Mutations
  module Sessions
    # Abandon an onboarding session explicitly
    #
    # AC 2.5.1: GraphQL mutation abandonSession(sessionId: ID!): Session! is implemented
    # AC 2.5.2: Mutation requires valid session token (cannot abandon others' sessions)
    # AC 2.5.3: Mutation sets session status to ABANDONED
    # AC 2.5.4: Session data is retained per data retention policy (same as expiration)
    # AC 2.5.5: Parent can create a new session immediately after abandonment
    # AC 2.5.6: Abandoned session cannot be resumed (mutation returns error if attempted)
    # AC 2.5.7: Response confirms abandonment with session ID and new status
    # AC 2.5.8: Audit log entry created: action: SESSION_ABANDONED, details: { previousStatus }
    #
    # Client-Side Confirmation:
    # AC 2.5.9: This mutation assumes the client has already obtained user confirmation
    # before calling. Recommended confirmation dialog:
    #
    #   "Are you sure you want to abandon this session? Your progress will be saved,
    #    but you won't be able to resume this session. You can start a new session
    #    at any time."
    #
    # The backend does not enforce confirmation - this is a client responsibility.
    #
    # Authorization Pattern:
    # Session ownership is verified via JWT token comparison. The session_id claim
    # in the JWT token must match the sessionId argument. Users cannot abandon
    # sessions they don't own.
    #
    # Idempotency:
    # Abandoning an already abandoned session returns success (not error) per tech spec.
    # This allows clients to retry safely without special handling.
    #
    # Example usage:
    #   mutation {
    #     abandonSession(sessionId: "sess_clx123...") {
    #       session {
    #         id
    #         status
    #       }
    #       success
    #     }
    #   }
    class AbandonSession < BaseMutation
      description <<~DESC
        Abandon an onboarding session explicitly.

        The session status will be set to ABANDONED and the session can no longer
        be resumed or updated. All session data is retained per the data retention
        policy (90 days, same as expired sessions).

        **Authorization:** Requires valid session token. Users can only abandon
        their own sessions.

        **Client-side confirmation:** Clients should display a confirmation dialog
        before calling this mutation. Recommended message:

        "Are you sure you want to abandon this session? Your progress will be saved,
        but you won't be able to resume this session. You can start a new session
        at any time."

        **Idempotency:** Calling this mutation on an already abandoned session
        will succeed without error.
      DESC

      argument :session_id, ID, required: true,
               description: "The ID of the session to abandon"

      field :session, Types::OnboardingSessionType, null: false,
            description: "The abandoned session with updated status"

      field :success, Boolean, null: false,
            description: "Indicates if the abandonment was successful"

      def resolve(session_id:)
        # Load the session
        session = OnboardingSession.find(session_id)

        # AC 2.5.2: Authorization check - verify session ownership
        # This raises Pundit::NotAuthorizedError if user doesn't own the session
        authorize(session, :abandon?)

        # Build context for audit logging
        # AC 2.5.8: Record IP address and user agent from context
        audit_context = {
          ip_address: context[:ip_address],
          user_agent: context[:user_agent]
        }

        # AC 2.5.3: Abandon the session (sets status to ABANDONED)
        # AC 2.5.4: No data deletion - all session data retained
        # AC 2.5.8: Creates audit log with previousStatus in details
        session.abandon!(context: audit_context)

        # AC 2.5.7: Response confirms abandonment with session ID and new status
        {
          session: session.reload,
          success: true
        }
      rescue ActiveRecord::RecordNotFound
        raise GraphQL::ExecutionError.new(
          'Session not found',
          extensions: { code: Errors::ErrorCodes::NOT_FOUND }
        )
      rescue Pundit::NotAuthorizedError
        # AC 2.5.2: Return FORBIDDEN error if trying to abandon another user's session
        raise GraphQL::ExecutionError.new(
          'You do not have permission to abandon this session',
          extensions: { code: Errors::ErrorCodes::FORBIDDEN }
        )
      rescue ActiveRecord::RecordInvalid => e
        # Invalid state transition (shouldn't happen with current state machine)
        raise GraphQL::ExecutionError.new(
          "Failed to abandon session: #{e.message}",
          extensions: { code: Errors::ErrorCodes::VALIDATION_ERROR }
        )
      end

      # Helper to get current user from GraphQL context
      # This is set by GraphqlController based on JWT token
      def current_user
        context[:current_user]
      end
    end
  end
end
