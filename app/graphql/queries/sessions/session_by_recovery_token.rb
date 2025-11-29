# frozen_string_literal: true

module Queries
  module Sessions
    # Session recovery query
    #
    # Validates recovery token and returns session with new JWT.
    # No authentication required (token is the credential).
    #
    # Example:
    #   query {
    #     sessionByRecoveryToken(recoveryToken: "abc123...") {
    #       session { id status progress }
    #       token
    #       refreshToken
    #     }
    #   }
    class SessionByRecoveryToken < Queries::BaseQuery
      description "Recover session using magic link token"

      # Arguments
      argument :recovery_token, String, required: true,
        description: "Recovery token from email magic link"

      # Return type
      type Types::SessionRecoveryPayloadType, null: false

      # Resolver
      def resolve(recovery_token:)
        # Validate recovery token and get session ID
        # Token is automatically deleted (one-time use)
        session_id = Auth::RecoveryTokenService.validate_recovery_token(recovery_token)

        unless session_id
          raise GraphQL::ExecutionError,
                "Invalid or expired recovery token. Please request a new recovery link."
        end

        # Fetch session by ID
        session = OnboardingSession.find_by(id: session_id)

        unless session
          raise GraphQL::ExecutionError,
                "Session not found. It may have been deleted."
        end

        # Verify session is not expired or abandoned
        unless session.active?
          raise GraphQL::ExecutionError,
                "Session is #{session.status} and cannot be recovered. Please start a new session."
        end

        # Generate new JWT token for session
        jwt_token = Auth::JwtService.encode({
          session_id: session.id,
          role: 'parent'
        })

        # Generate new refresh token with device fingerprint
        # Device fingerprint is calculated from user agent and IP for security tracking
        device_fingerprint = Digest::SHA256.hexdigest("#{context[:user_agent]}#{context[:ip_address]}")
        refresh_token = Auth::TokenService.generate_refresh_token(
          session,
          device_fingerprint: device_fingerprint,
          ip_address: context[:ip_address],
          user_agent: context[:user_agent]
        )

        # Create audit log for successful recovery
        AuditLog.create!(
          action: 'SESSION_RECOVERED',
          resource: 'OnboardingSession',
          resource_id: session.id,
          onboarding_session: session,
          details: {
            device: context[:user_agent],
            ip: context[:ip_address],
            recovered_at: Time.current
          },
          ip_address: context[:ip_address],
          user_agent: context[:user_agent]
        )

        # Return session with new tokens
        {
          session: session,
          token: jwt_token,
          refresh_token: refresh_token
        }
      end
    end
  end
end
