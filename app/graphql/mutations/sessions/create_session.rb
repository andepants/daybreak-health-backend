# frozen_string_literal: true

module Mutations
  module Sessions
    class CreateSession < GraphQL::Schema::Mutation
      description 'Create a new anonymous onboarding session'

      argument :referral_source, String, required: false,
        description: 'How the parent found Daybreak (e.g., Google, referral, social media)'
      argument :device_fingerprint, String, required: false,
        description: 'Device fingerprint for refresh token generation'

      field :session, Types::OnboardingSessionType, null: false
      field :token, String, null: false
      field :refresh_token, String, null: true, description: 'Refresh token for obtaining new access tokens'

      def resolve(referral_source: nil, device_fingerprint: nil)
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
        token = ::Auth::JwtService.encode(
          { session_id: session.id, role: 'anonymous' },
          exp: token_expiration.from_now
        )

        # Generate refresh token if device fingerprint provided (or generate one)
        refresh_token = generate_refresh_token(session, device_fingerprint)

        # Create audit log entry
        create_audit_log(session)

        # Return response
        {
          session: session,
          token: token,
          refresh_token: refresh_token
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

      # Generate refresh token for the session
      #
      # @param session [OnboardingSession] Created session
      # @param device_fingerprint [String, nil] Optional device fingerprint
      # @return [String, nil] Refresh token or nil if generation fails
      def generate_refresh_token(session, device_fingerprint)
        # Generate fingerprint if not provided
        fingerprint = device_fingerprint || generate_device_fingerprint

        ::Auth::TokenService.generate_refresh_token(
          session,
          device_fingerprint: fingerprint,
          ip_address: context[:ip_address],
          user_agent: context[:user_agent]
        )
      rescue StandardError => e
        Rails.logger.error("Refresh token generation failed: #{e.message}")
        nil
      end

      # Generate a device fingerprint from request context
      #
      # @return [String] SHA256 hash of device identifiers
      def generate_device_fingerprint
        components = [
          context[:ip_address],
          context[:user_agent],
          Time.current.to_i
        ].compact.join('-')

        Digest::SHA256.hexdigest(components)
      end

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
