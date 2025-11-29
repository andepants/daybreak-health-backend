# frozen_string_literal: true

module Auth
  # Authentication audit logging service
  #
  # AC 2.6.10: Audit log captures all authentication events
  #
  # Events logged:
  # - JWT_CREATED: When new access token issued
  # - JWT_REFRESH: When access token refreshed
  # - JWT_INVALID: When invalid token used
  # - JWT_EXPIRED: When expired token used
  # - AUTH_FAILED: When authentication fails
  # - AUTHZ_DENIED: When authorization check fails (403)
  # - RATE_LIMITED: When rate limit exceeded
  # - REFRESH_TOKEN_CREATED: When refresh token generated
  # - REFRESH_TOKEN_ROTATED: When refresh token rotated
  # - REFRESH_TOKEN_REVOKED: When refresh token revoked
  #
  # All events include IP address and user agent for security tracking.
  # PHI-safe: Never logs actual PHI values, only references.
  #
  # Example usage:
  #   Auth::AuditService.log_jwt_created(
  #     session_id: session.id,
  #     role: 'parent',
  #     ip_address: request.ip,
  #     user_agent: request.user_agent
  #   )
  class AuditService
    class << self
      # Log successful JWT creation
      # AC 2.6.10: Log successful JWT creation with session_id
      #
      # @param session_id [String] Session ID
      # @param role [String] User role
      # @param ip_address [String] Client IP address
      # @param user_agent [String] Client user agent
      def log_jwt_created(session_id:, role:, ip_address: nil, user_agent: nil)
        create_audit_log(
          action: 'JWT_CREATED',
          session_id: session_id,
          details: {
            role: role,
            expires_at: 1.hour.from_now.iso8601
          },
          ip_address: ip_address,
          user_agent: user_agent
        )
      end

      # Log JWT refresh
      # AC 2.6.10: Log refresh token generation and rotation
      #
      # @param session_id [String] Session ID
      # @param role [String] User role
      # @param ip_address [String] Client IP address
      # @param user_agent [String] Client user agent
      def log_jwt_refresh(session_id:, role:, ip_address: nil, user_agent: nil)
        create_audit_log(
          action: 'JWT_REFRESH',
          session_id: session_id,
          details: {
            role: role,
            expires_at: 1.hour.from_now.iso8601
          },
          ip_address: ip_address,
          user_agent: user_agent
        )
      end

      # Log invalid JWT attempt
      # AC 2.6.10: Log failed authentication attempts with reason
      #
      # @param reason [String] Reason for invalidity
      # @param ip_address [String] Client IP address
      # @param user_agent [String] Client user agent
      def log_jwt_invalid(reason:, ip_address: nil, user_agent: nil)
        create_audit_log(
          action: 'JWT_INVALID',
          session_id: nil,
          details: { reason: reason },
          ip_address: ip_address,
          user_agent: user_agent
        )
      end

      # Log expired JWT attempt
      # AC 2.6.10: Log failed authentication attempts with reason
      #
      # @param session_id [String] Session ID from expired token
      # @param ip_address [String] Client IP address
      # @param user_agent [String] Client user agent
      def log_jwt_expired(session_id: nil, ip_address: nil, user_agent: nil)
        create_audit_log(
          action: 'JWT_EXPIRED',
          session_id: session_id,
          details: { reason: 'Token has expired' },
          ip_address: ip_address,
          user_agent: user_agent
        )
      end

      # Log authentication failure
      # AC 2.6.10: Log failed authentication attempts with reason
      #
      # @param reason [String] Reason for failure
      # @param ip_address [String] Client IP address
      # @param user_agent [String] Client user agent
      def log_auth_failed(reason:, ip_address: nil, user_agent: nil)
        create_audit_log(
          action: 'AUTH_FAILED',
          session_id: nil,
          details: { reason: reason },
          ip_address: ip_address,
          user_agent: user_agent
        )
      end

      # Log authorization denial (403)
      # AC 2.6.10: Log authorization failures with attempted action
      #
      # @param session_id [String] Session ID
      # @param resource_type [String] Resource type attempted to access
      # @param resource_id [String] Resource ID attempted to access
      # @param action [String] Action attempted
      # @param role [String] User role
      # @param ip_address [String] Client IP address
      # @param user_agent [String] Client user agent
      def log_authz_denied(session_id:, resource_type:, resource_id:, action:, role:, ip_address: nil, user_agent: nil)
        create_audit_log(
          action: 'AUTHZ_DENIED',
          session_id: session_id,
          details: {
            resource_type: resource_type,
            resource_id: resource_id,
            attempted_action: action,
            role: role
          },
          ip_address: ip_address,
          user_agent: user_agent
        )
      end

      # Log rate limit exceeded
      # AC 2.6.10: Log rate limit events
      #
      # @param identifier [String] User identifier (session_id or IP)
      # @param role [String] User role
      # @param limit [Integer] Rate limit threshold
      # @param ip_address [String] Client IP address
      # @param user_agent [String] Client user agent
      def log_rate_limited(identifier:, role:, limit:, ip_address: nil, user_agent: nil)
        create_audit_log(
          action: 'RATE_LIMITED',
          session_id: nil,
          details: {
            identifier: identifier,
            role: role,
            limit: limit
          },
          ip_address: ip_address,
          user_agent: user_agent
        )
      end

      # Log refresh token creation
      # AC 2.6.10: Log refresh token generation and rotation
      #
      # @param session_id [String] Session ID
      # @param device_fingerprint [String] Device fingerprint
      # @param ip_address [String] Client IP address
      # @param user_agent [String] Client user agent
      def log_refresh_token_created(session_id:, device_fingerprint:, ip_address: nil, user_agent: nil)
        create_audit_log(
          action: 'REFRESH_TOKEN_CREATED',
          session_id: session_id,
          details: {
            device_fingerprint: device_fingerprint,
            expires_at: 7.days.from_now.iso8601
          },
          ip_address: ip_address,
          user_agent: user_agent
        )
      end

      # Log refresh token rotation
      # AC 2.6.10: Log refresh token generation and rotation
      #
      # @param session_id [String] Session ID
      # @param device_fingerprint [String] Device fingerprint
      # @param ip_address [String] Client IP address
      # @param user_agent [String] Client user agent
      def log_refresh_token_rotated(session_id:, device_fingerprint:, ip_address: nil, user_agent: nil)
        create_audit_log(
          action: 'REFRESH_TOKEN_ROTATED',
          session_id: session_id,
          details: {
            device_fingerprint: device_fingerprint,
            new_expires_at: 7.days.from_now.iso8601
          },
          ip_address: ip_address,
          user_agent: user_agent
        )
      end

      # Log refresh token revocation
      # AC 2.6.10: Log refresh token generation and rotation
      #
      # @param session_id [String] Session ID
      # @param reason [String] Reason for revocation
      # @param ip_address [String] Client IP address
      # @param user_agent [String] Client user agent
      def log_refresh_token_revoked(session_id:, reason: 'User initiated', ip_address: nil, user_agent: nil)
        create_audit_log(
          action: 'REFRESH_TOKEN_REVOKED',
          session_id: session_id,
          details: { reason: reason },
          ip_address: ip_address,
          user_agent: user_agent
        )
      end

      private

      # Create an audit log entry
      #
      # @param action [String] Action type
      # @param session_id [String, nil] Session ID
      # @param details [Hash] Additional details
      # @param ip_address [String, nil] Client IP address
      # @param user_agent [String, nil] Client user agent
      def create_audit_log(action:, session_id:, details:, ip_address:, user_agent:)
        AuditLog.create!(
          onboarding_session_id: session_id,
          action: action,
          resource: 'Authentication',
          resource_id: session_id,
          details: details,
          ip_address: ip_address,
          user_agent: user_agent
        )
      rescue StandardError => e
        # Don't let audit logging failures prevent authentication
        Rails.logger.error("Auth audit logging failed: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end
  end
end
