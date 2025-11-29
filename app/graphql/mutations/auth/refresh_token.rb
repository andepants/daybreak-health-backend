# frozen_string_literal: true

module Mutations
  module Auth
    class RefreshToken < GraphQL::Schema::Mutation
      description 'Refresh access token using a valid refresh token. Implements token rotation for security.'

      argument :refresh_token, String, required: true,
        description: 'The refresh token received from createSession or previous refresh'
      argument :device_fingerprint, String, required: false,
        description: 'Device fingerprint for security tracking'

      field :token, String, null: true, description: 'New JWT access token'
      field :refresh_token, String, null: true, description: 'New refresh token (old one is invalidated)'
      field :token_type, String, null: true, description: 'Token type (Bearer)'
      field :expires_in, Integer, null: true, description: 'Access token expiration in seconds'
      field :success, Boolean, null: false, description: 'Whether the refresh was successful'
      field :error, String, null: true, description: 'Error message if refresh failed'

      def resolve(refresh_token:, device_fingerprint: nil)
        # Generate device fingerprint if not provided
        fingerprint = device_fingerprint || generate_fingerprint

        # Validate and rotate the refresh token
        result = ::Auth::TokenService.validate_refresh_token(
          refresh_token,
          device_fingerprint: fingerprint,
          ip_address: context[:ip_address],
          user_agent: context[:user_agent]
        )

        if result.nil?
          create_audit_log_failure
          return {
            success: false,
            error: 'Invalid or expired refresh token',
            token: nil,
            refresh_token: nil,
            token_type: nil,
            expires_in: nil
          }
        end

        session = result[:session]
        new_refresh_token = result[:new_token]

        # Generate new access token
        token_expiration = ENV.fetch('SESSION_TOKEN_EXPIRATION_HOURS', 1).to_i.hours
        access_token = ::Auth::JwtService.encode(
          { session_id: session.id, role: 'anonymous' },
          exp: token_expiration.from_now
        )

        # Create audit log entry
        create_audit_log_success(session)

        {
          success: true,
          error: nil,
          token: access_token,
          refresh_token: new_refresh_token,
          token_type: 'Bearer',
          expires_in: token_expiration.to_i
        }
      rescue StandardError => e
        Rails.logger.error("Token refresh failed: #{e.message}")
        {
          success: false,
          error: 'Token refresh failed',
          token: nil,
          refresh_token: nil,
          token_type: nil,
          expires_in: nil
        }
      end

      private

      def generate_fingerprint
        # Generate a fingerprint from available context
        components = [
          context[:ip_address],
          context[:user_agent],
          Time.current.to_i
        ].compact.join('-')

        Digest::SHA256.hexdigest(components)
      end

      def create_audit_log_success(session)
        AuditLog.create!(
          action: 'TOKEN_REFRESHED',
          resource: 'RefreshToken',
          resource_id: session.id,
          onboarding_session_id: session.id,
          ip_address: context[:ip_address],
          user_agent: context[:user_agent],
          details: {
            session_status: session.status
          }
        )
      rescue StandardError => e
        Rails.logger.error("Audit log creation failed: #{e.message}")
      end

      def create_audit_log_failure
        AuditLog.create!(
          action: 'TOKEN_REFRESH_FAILED',
          resource: 'RefreshToken',
          resource_id: nil,
          onboarding_session_id: nil,
          ip_address: context[:ip_address],
          user_agent: context[:user_agent],
          details: {
            reason: 'Invalid or expired refresh token'
          }
        )
      rescue StandardError => e
        Rails.logger.error("Audit log creation failed: #{e.message}")
      end
    end
  end
end
