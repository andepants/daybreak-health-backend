# frozen_string_literal: true

module Mutations
  module Sessions
    # Request human assistance during onboarding session
    #
    # AC 3.5.2: Session flagged for human follow-up: escalation_requested: true in metadata
    # AC 3.5.3: Session needs_human_contact flag set to true in OnboardingSession model
    # AC 3.5.7: Escalation reason captured if provided by parent
    # AC 3.5.6: Care team notified of escalation request
    #
    # Authorization Pattern:
    # Session ownership is verified via JWT token comparison. The session_id claim
    # in the JWT token must match the sessionId argument. Users cannot escalate
    # sessions they don't own.
    #
    # Idempotency:
    # Requesting escalation on an already escalated session returns success (not error).
    # This prevents duplicate notifications - the flag is simply checked and if already
    # set, we return the existing state without re-notifying the care team.
    #
    # Example usage:
    #   mutation {
    #     requestHumanContact(sessionId: "sess_clx123...", reason: "I need urgent help") {
    #       session {
    #         id
    #         needsHumanContact
    #         escalationRequestedAt
    #       }
    #       success
    #     }
    #   }
    class RequestHumanContact < BaseMutation
      description <<~DESC
        Request to speak with a human during the onboarding process.

        This mutation flags the session for human follow-up and notifies the care team.
        The parent can optionally provide a reason for the escalation request.

        The onboarding conversation can continue with AI assistance while waiting
        for human contact, and all collected data is preserved.

        **Authorization:** Requires valid session token. Users can only request
        human contact for their own sessions.

        **Idempotency:** Calling this mutation on an already escalated session
        will succeed without duplicate notifications.
      DESC

      argument :session_id, ID, required: true,
               description: "The ID of the session requesting human contact"

      argument :reason, String, required: false,
               description: "Optional reason for requesting human assistance (PHI-encrypted)"

      field :session, Types::OnboardingSessionType, null: false,
            description: "The session with escalation status updated"

      field :success, Boolean, null: false,
            description: "Indicates if the escalation request was successful"

      def resolve(session_id:, reason: nil)
        # Extract UUID from session_id (remove sess_ prefix)
        uuid = extract_uuid(session_id)

        # Load the session
        session = OnboardingSession.find(uuid)

        # AC 3.5.2,3.5.3: Authorization check - verify session ownership
        authorize_session!(session)

        # AC 3.5.2,3.5.3: Check idempotency - if already escalated, return existing state
        if session.needs_human_contact
          Rails.logger.info("Duplicate escalation request for session #{session_id} - idempotent response")
          return {
            session: session,
            success: true
          }
        end

        # AC 3.5.2,3.5.3: Set escalation flags
        session.needs_human_contact = true
        session.escalation_requested_at = Time.current

        # AC 3.5.7: Store encrypted escalation reason if provided
        session.escalation_reason = reason if reason.present?

        # Save the session with transaction
        ActiveRecord::Base.transaction do
          session.save!

          # AC 3.5.6: Create audit log entry for escalation request
          create_escalation_audit_log(session, reason)

          # AC 3.5.6: Trigger care team notification asynchronously
          # Using perform_later for immediate queueing (ActiveJob pattern)
          EscalationNotificationJob.perform_later(session.id)
        end

        {
          session: session.reload,
          success: true
        }
      rescue ActiveRecord::RecordNotFound
        raise GraphQL::ExecutionError.new(
          'Session not found',
          extensions: { code: GraphqlErrors::ErrorCodes::NOT_FOUND }
        )
      rescue GraphQL::ExecutionError
        # Re-raise execution errors (including authorization errors)
        raise
      rescue ActiveRecord::RecordInvalid => e
        raise GraphQL::ExecutionError.new(
          "Failed to request human contact: #{e.message}",
          extensions: { code: GraphqlErrors::ErrorCodes::VALIDATION_ERROR }
        )
      end

      private

      # Extract UUID from session_id (remove sess_ prefix)
      #
      # @param session_id [String] Session ID with optional sess_ prefix
      # @return [String] UUID
      def extract_uuid(session_id)
        # Remove sess_ prefix and reformat as UUID
        clean_id = session_id.to_s.gsub(/^sess_/, "")

        # Add dashes back to UUID format if needed
        if clean_id.length == 32 && !clean_id.include?("-")
          # Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
          "#{clean_id[0..7]}-#{clean_id[8..11]}-#{clean_id[12..15]}-#{clean_id[16..19]}-#{clean_id[20..31]}"
        else
          clean_id
        end
      end

      # Authorize session access
      # Ensures user can only request human contact for their own session
      #
      # @param session [OnboardingSession] Session to authorize
      # @raise [GraphQL::ExecutionError] If unauthorized
      def authorize_session!(session)
        # Check both context[:current_session] (from GraphqlController) and context[:current_session_id]
        current_session = context[:current_session]
        current_session_id = current_session&.id || context[:current_session_id]

        if current_session_id.blank?
          raise GraphQL::ExecutionError.new(
            'You do not have permission to request human contact for this session',
            extensions: { code: GraphqlErrors::ErrorCodes::FORBIDDEN }
          )
        end

        # Verify session belongs to current user (session ID must match)
        unless session.id == current_session_id
          raise GraphQL::ExecutionError.new(
            'You do not have permission to request human contact for this session',
            extensions: { code: GraphqlErrors::ErrorCodes::FORBIDDEN }
          )
        end
      end

      # Create audit log entry for escalation request
      # AC 3.5.6: action: HUMAN_ESCALATION_REQUESTED
      def create_escalation_audit_log(session, reason)
        AuditLog.create!(
          onboarding_session_id: session.id,
          action: 'HUMAN_ESCALATION_REQUESTED',
          resource: 'OnboardingSession',
          resource_id: session.id,
          details: {
            escalation_requested_at: session.escalation_requested_at.iso8601,
            has_reason: reason.present?,
            timestamp: Time.current.iso8601
          },
          ip_address: context[:ip_address],
          user_agent: context[:user_agent]
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
