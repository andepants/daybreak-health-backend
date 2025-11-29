# frozen_string_literal: true

module Auth
  # Refresh token management service
  #
  # Handles generation and validation of refresh tokens for session persistence.
  # Implements token rotation to prevent token reuse attacks.
  #
  # Security constraints:
  # - Tokens are hashed with bcrypt before storage (never stored in plaintext)
  # - Tokens expire after 7 days
  # - Device fingerprinting for tracking and security
  # - Tokens are revoked (soft deleted) on use for rotation
  # - Uses cryptographically secure random generation
  #
  # Example usage:
  #   # Generate
  #   token = Auth::TokenService.generate_refresh_token(
  #     session,
  #     device_fingerprint: 'abc123',
  #     ip_address: '192.168.1.1',
  #     user_agent: 'Mozilla/5.0...'
  #   )
  #
  #   # Validate and rotate
  #   result = Auth::TokenService.validate_refresh_token(
  #     token,
  #     device_fingerprint: 'abc123',
  #     ip_address: '192.168.1.1',
  #     user_agent: 'Mozilla/5.0...'
  #   )
  #   # Returns { session: session, new_token: 'new_token_string' } or nil
  class TokenService
    TOKEN_LENGTH = 64 # characters
    TOKEN_EXPIRATION = 7.days

    class << self
      # Generate a refresh token for a session
      #
      # AC 2.6.2: Token refresh mechanism with 7-day refresh tokens stored securely
      #
      # @param session [OnboardingSession] Session to create token for
      # @param device_fingerprint [String] Unique device identifier
      # @param ip_address [String] Client IP address
      # @param user_agent [String] Client user agent string
      # @return [String] Generated refresh token (plaintext, only returned once)
      #
      # @example
      #   token = Auth::TokenService.generate_refresh_token(
      #     session,
      #     device_fingerprint: Digest::SHA256.hexdigest(user_agent + ip),
      #     ip_address: request.ip,
      #     user_agent: request.user_agent
      #   )
      def generate_refresh_token(session, device_fingerprint:, ip_address: nil, user_agent: nil)
        raise ArgumentError, 'Session must be an OnboardingSession' unless session.is_a?(OnboardingSession)
        raise ArgumentError, 'Session must be persisted' unless session.persisted?
        raise ArgumentError, 'Device fingerprint is required' if device_fingerprint.blank?

        token = generate_secure_token

        # Create RefreshToken record with bcrypt hashed token
        RefreshToken.create!(
          onboarding_session: session,
          token: token, # Virtual attribute, will be hashed by before_create callback
          device_fingerprint: device_fingerprint,
          ip_address: ip_address,
          user_agent: user_agent,
          expires_at: TOKEN_EXPIRATION.from_now
        )

        # Return plaintext token (only time it's available)
        token
      end

      # Validate a refresh token and return the associated session with new token
      # AC 2.6.2: Token rotation (invalidate old token on refresh)
      #
      # This implements token rotation for security:
      # 1. Validates the token exists and matches
      # 2. Revokes the old token (one-time use)
      # 3. Generates a new refresh token
      # 4. Returns session and new token
      #
      # @param token [String] Refresh token to validate
      # @param device_fingerprint [String] Device fingerprint for rotation
      # @param ip_address [String] IP address for new token
      # @param user_agent [String] User agent for new token
      # @return [Hash, nil] { session: OnboardingSession, new_token: String } or nil if invalid
      #
      # @example
      #   result = Auth::TokenService.validate_refresh_token(
      #     token,
      #     device_fingerprint: 'abc123',
      #     ip_address: '192.168.1.1',
      #     user_agent: 'Mozilla/5.0...'
      #   )
      #   if result
      #     session = result[:session]
      #     new_token = result[:new_token]
      #   end
      def validate_refresh_token(token, device_fingerprint:, ip_address: nil, user_agent: nil)
        return nil if token.blank?

        # Find all refresh tokens (we'll filter manually since tokens are hashed)
        # First get only non-revoked, non-expired tokens
        valid_tokens = RefreshToken.valid.includes(:onboarding_session)

        # Find the matching token by checking hash
        refresh_token = valid_tokens.find { |rt| rt.token_matches?(token) }
        return nil if refresh_token.nil?

        session = refresh_token.onboarding_session
        return nil if session.nil?

        # AC 2.6.2: Token rotation - revoke the old token
        refresh_token.revoke!

        # Generate new refresh token for continued access
        new_token = generate_refresh_token(
          session,
          device_fingerprint: device_fingerprint,
          ip_address: ip_address,
          user_agent: user_agent
        )

        # Return both session and new token
        {
          session: session,
          new_token: new_token
        }
      end

      # Invalidate a refresh token (revoke)
      #
      # @param token [String] Token to invalidate
      # @return [Boolean] true if token was found and revoked
      #
      # @example
      #   Auth::TokenService.invalidate_token(token)
      def invalidate_token(token)
        return false if token.blank?

        # Find all non-revoked tokens and check for match
        valid_tokens = RefreshToken.where(revoked_at: nil)
        refresh_token = valid_tokens.find { |rt| rt.token_matches?(token) }

        return false if refresh_token.nil?

        refresh_token.revoke!
        true
      end

      # Invalidate all tokens for a session
      #
      # @param session [OnboardingSession] Session to invalidate tokens for
      # @return [Integer] Number of tokens invalidated
      #
      # @example
      #   Auth::TokenService.invalidate_all_tokens(session)
      def invalidate_all_tokens(session)
        count = session.refresh_tokens.where(revoked_at: nil).count
        session.refresh_tokens.where(revoked_at: nil).update_all(revoked_at: Time.current)
        count
      end

      # Cleanup expired tokens (called by background job)
      # Permanently deletes tokens that have been expired for more than 90 days
      #
      # @return [Integer] Number of tokens deleted
      def cleanup_expired_tokens
        cutoff = 90.days.ago
        RefreshToken.expired.where('expires_at < ?', cutoff).delete_all
      end

      private

      # Generate a cryptographically secure random token
      #
      # @return [String] Random token
      def generate_secure_token
        SecureRandom.urlsafe_base64(TOKEN_LENGTH)
      end
    end
  end
end
