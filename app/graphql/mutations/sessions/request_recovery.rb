# frozen_string_literal: true

module Mutations
  module Sessions
    # Request session recovery mutation
    #
    # Sends a magic link email to the parent for session recovery.
    # Requires authenticated session token.
    #
    # Example:
    #   mutation {
    #     requestSessionRecovery(input: { sessionId: "sess_123" }) {
    #       success
    #       message
    #     }
    #   }
    class RequestRecovery < BaseMutation
      description "Request session recovery via email magic link"

      # Input
      argument :session_id, ID, required: true,
        description: "ID of the session to recover"

      # Output
      field :success, Boolean, null: false,
        description: "Whether the request was successful"
      field :message, String, null: false,
        description: "Human-readable message"

      # Resolver
      def resolve(session_id:)
        # Load session
        session = OnboardingSession.find_by(id: session_id)

        unless session
          raise GraphQL::ExecutionError, "Session not found"
        end

        # Verify parent email exists
        unless session.parent&.email.present?
          raise GraphQL::ExecutionError,
                "Parent email not collected yet. Please provide your email before requesting recovery."
        end

        # Verify session is active (not expired/abandoned)
        unless session.active?
          raise GraphQL::ExecutionError,
                "Session is #{session.status} and cannot be recovered"
        end

        parent = session.parent

        begin
          # Generate recovery token
          recovery_token = Auth::RecoveryTokenService.generate_recovery_token(
            session_id: session.id,
            email: parent.email
          )

          # Build recovery URL (frontend URL with token)
          # In production, this should come from environment config
          base_url = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
          recovery_url = "#{base_url}/recover-session?token=#{recovery_token}"

          # Send recovery email
          ParentMailer.session_recovery(
            parent: parent,
            recovery_url: recovery_url
          ).deliver_later

          # Create audit log (PHI-safe: no email stored)
          AuditLog.create!(
            action: 'SESSION_RECOVERY_REQUESTED',
            resource: 'OnboardingSession',
            resource_id: session.id,
            onboarding_session: session,
            details: {
              requested_at: Time.current
            },
            ip_address: context[:ip_address],
            user_agent: context[:user_agent]
          )

          {
            success: true,
            message: "Recovery link sent to your email"
          }
        rescue Auth::RecoveryTokenService::RateLimitExceededError => e
          raise GraphQL::ExecutionError, e.message
        end
      end
    end
  end
end
