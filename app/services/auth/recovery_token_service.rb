# frozen_string_literal: true

module Auth
  # Session recovery token management service
  #
  # Handles generation and validation of recovery tokens for session recovery via magic links.
  # Implements one-time use and rate limiting to prevent abuse.
  #
  # Security constraints:
  # - Tokens are cryptographically secure (32 bytes, hex-encoded)
  # - Tokens expire after 15 minutes
  # - Tokens are one-time use (deleted after successful validation)
  # - Rate limiting: max 3 recovery requests per hour per email
  #
  # Multi-Device Philosophy:
  # - Session recovery does NOT invalidate existing JWT tokens
  # - Multiple devices can access the same session simultaneously
  # - This prioritizes UX (seamless multi-device experience) over strict security
  # - Session expiration still applies globally regardless of number of active tokens
  # - Security trade-off: If a token is compromised, attacker has access until token expires (1 hour)
  #   or session expires (24 hours). This is acceptable for the use case given the low-risk nature
  #   of onboarding data and the UX benefit of multi-device support.
  #
  # Example usage:
  #   # Generate recovery token
  #   token = Auth::RecoveryTokenService.generate_recovery_token(
  #     session_id: session.id,
  #     email: parent.email
  #   )
  #
  #   # Validate and consume token
  #   session_id = Auth::RecoveryTokenService.validate_recovery_token(token)
  #   # Returns session_id and deletes token (one-time use)
  class RecoveryTokenService
    TOKEN_BYTES = 32 # bytes (results in 64 hex characters)
    TOKEN_EXPIRATION = 15.minutes
    REDIS_TOKEN_PREFIX = 'recovery:'
    REDIS_RATE_PREFIX = 'recovery_rate:'
    RATE_LIMIT_MAX = 3
    RATE_LIMIT_WINDOW = 1.hour

    class RateLimitExceededError < StandardError; end

    class << self
      # Generate a recovery token for a session
      #
      # @param session_id [String] Session ID to create token for
      # @param email [String] Parent email for rate limiting
      # @return [String] Generated recovery token (hex-encoded)
      # @raise [RateLimitExceededError] If rate limit exceeded
      #
      # @example
      #   token = Auth::RecoveryTokenService.generate_recovery_token(
      #     session_id: 'sess_123',
      #     email: 'parent@example.com'
      #   )
      def generate_recovery_token(session_id:, email:)
        raise ArgumentError, 'Session ID must be present' if session_id.blank?
        raise ArgumentError, 'Email must be present' if email.blank?

        # Check rate limit before generating token
        check_rate_limit!(email)

        # Generate cryptographically secure token
        token = generate_secure_token

        # Store token in Redis with 15-minute expiration
        store_token(token, session_id)

        # Increment rate limit counter
        increment_rate_limit(email)

        token
      end

      # Validate a recovery token and return the associated session ID
      # Token is deleted (one-time use) after successful validation
      #
      # @param token [String] Recovery token to validate
      # @return [String, nil] Associated session ID or nil if invalid/expired
      #
      # @example
      #   session_id = Auth::RecoveryTokenService.validate_recovery_token(token)
      def validate_recovery_token(token)
        return nil if token.blank?

        # Retrieve and delete token in one atomic operation
        session_id = retrieve_and_delete_token(token)

        session_id
      end

      # Check if email has exceeded rate limit
      #
      # @param email [String] Email to check
      # @return [Boolean] true if rate limit exceeded
      #
      # @example
      #   if Auth::RecoveryTokenService.rate_limit_exceeded?(email)
      #     # Handle rate limit
      #   end
      def rate_limit_exceeded?(email)
        return false if email.blank?

        current_count = redis.get(rate_limit_key(email)).to_i
        current_count >= RATE_LIMIT_MAX
      end

      # Get current rate limit count for email
      #
      # @param email [String] Email to check
      # @return [Integer] Current request count
      def rate_limit_count(email)
        return 0 if email.blank?

        redis.get(rate_limit_key(email)).to_i
      end

      private

      # Check rate limit and raise error if exceeded
      #
      # @param email [String] Email to check
      # @raise [RateLimitExceededError] If limit exceeded
      def check_rate_limit!(email)
        if rate_limit_exceeded?(email)
          raise RateLimitExceededError,
                "Too many recovery requests. Please try again later."
        end
      end

      # Increment rate limit counter for email
      #
      # @param email [String] Email to increment
      def increment_rate_limit(email)
        key = rate_limit_key(email)

        # Use Redis transaction for atomic increment and expire
        redis.multi do |transaction|
          transaction.incr(key)
          transaction.expire(key, RATE_LIMIT_WINDOW.to_i)
        end
      end

      # Generate a cryptographically secure random token
      #
      # @return [String] Random token (hex-encoded)
      def generate_secure_token
        SecureRandom.hex(TOKEN_BYTES)
      end

      # Store token in Redis with expiration
      #
      # @param token [String] Token to store
      # @param session_id [String] Associated session ID
      def store_token(token, session_id)
        redis.setex(
          token_key(token),
          TOKEN_EXPIRATION.to_i,
          session_id
        )
      end

      # Retrieve and delete token (atomic operation for one-time use)
      #
      # @param token [String] Token to retrieve
      # @return [String, nil] Associated session ID or nil
      def retrieve_and_delete_token(token)
        key = token_key(token)

        # Use GETDEL for atomic get-and-delete (Redis 6.2+)
        # This ensures one-time use
        redis.getdel(key)
      end

      # Build Redis key for recovery token
      #
      # @param token [String] Token
      # @return [String] Redis key
      def token_key(token)
        "#{REDIS_TOKEN_PREFIX}#{token}"
      end

      # Build Redis key for rate limiting
      #
      # @param email [String] Email
      # @return [String] Redis key
      def rate_limit_key(email)
        # Use downcased email for rate limiting to prevent case-sensitivity bypass
        "#{REDIS_RATE_PREFIX}#{email.downcase}"
      end

      # Get Redis connection
      #
      # @return [Redis] Redis client
      def redis
        @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      end
    end
  end
end
