# frozen_string_literal: true

module Mutations
  module Sessions
    class CreateSession < GraphQL::Schema::Mutation
      description 'Create a new anonymous onboarding session'

      argument :referral_source, String, required: false,
        description: 'How the parent found Daybreak (e.g., Google, referral, social media)'

      field :session, Types::OnboardingSessionType, null: false
      field :token, String, null: false

      def resolve(referral_source: nil)
        # Get context for current_session if needed
        @context = context
        # Create onboarding session
        # ID will be auto-generated in CUID format by model callback
        session = OnboardingSession.create!(
          status: :started,
          progress: {},
          referral_source: referral_source,
          expires_at: 24.hours.from_now
        )

        # Generate JWT token with configurable expiration
        token_expiration = ENV.fetch('SESSION_TOKEN_EXPIRATION_HOURS', 1).to_i.hours
        token = Auth::JwtService.encode(
          { session_id: session.id, role: 'anonymous' },
          exp: token_expiration.from_now
        )

        # Create audit log entry
        create_audit_log(session)

        # Return response
        {
          session: session,
          token: token
        }
      rescue ActiveRecord::RecordInvalid => e
        raise GraphQL::ExecutionError.new(
          "Session creation failed: #{e.message}",
          extensions: {
            code: 'VALIDATION_ERROR',
            timestamp: Time.current.iso8601
          }
        )
      end

      private

      # Create audit log entry for session creation
      #
      # @param session [OnboardingSession] Created session
      def create_audit_log(session)
        AuditLog.create!(
          action: 'SESSION_CREATED',
          resource: 'OnboardingSession',
          resource_id: session.id,
          onboarding_session_id: session.id,
          ip_address: context[:ip_address],
          user_agent: context[:user_agent],
          details: {
            status: session.status,
            expires_at: session.expires_at,
            referral_source: session.referral_source
          }.compact
        )
      rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
        # Log database-related audit failures but don't block session creation
        Rails.logger.error("Audit log creation failed (database error): #{e.message}")
        # Consider alerting on repeated failures in production
      rescue StandardError => e
        # Log other audit failures and re-raise if critical
        Rails.logger.error("Audit log creation failed: #{e.message}")
        # Re-raise validation errors as they indicate a code issue
        raise if e.is_a?(ActiveRecord::RecordInvalid)
      end
    end
  end
end
