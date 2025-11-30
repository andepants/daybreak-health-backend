# frozen_string_literal: true

module Auth
  # Service for generating and validating session recovery tokens
  #
  # Recovery tokens are short-lived (15 minutes) cryptographically secure tokens
  # that allow parents to resume their onboarding session via magic link.
  # Stored in Redis with session_recovery:#{session_id} key pattern.
  class RecoveryTokenService
    REDIS_KEY_PREFIX = "session_recovery:"
    TOKEN_TTL = 15.minutes.to_i

    class << self
      # Generate a new recovery token for a session
      #
      # @param session_id [String] UUID of the onboarding session
      # @return [String] Cryptographically secure recovery token (32 bytes, base64-encoded)
      def generate(session_id)
        token = SecureRandom.urlsafe_base64(32)
        redis_key = "#{REDIS_KEY_PREFIX}#{session_id}"

        # Store token in Redis with 15-minute TTL
        redis.setex(redis_key, TOKEN_TTL, token)

        token
      end

      # Validate a recovery token for a session
      #
      # @param session_id [String] UUID of the onboarding session
      # @param token [String] Recovery token to validate
      # @return [Boolean] True if token is valid and matches
      def valid?(session_id, token)
        return false if token.blank?

        redis_key = "#{REDIS_KEY_PREFIX}#{session_id}"
        stored_token = redis.get(redis_key)

        stored_token.present? && stored_token == token
      end

      # Consume a recovery token (one-time use)
      #
      # Validates the token and deletes it from Redis if valid.
      # Ensures tokens can only be used once.
      #
      # @param session_id [String] UUID of the onboarding session
      # @param token [String] Recovery token to consume
      # @return [Boolean] True if token was valid and consumed
      def consume(session_id, token)
        return false unless valid?(session_id, token)

        redis_key = "#{REDIS_KEY_PREFIX}#{session_id}"
        redis.del(redis_key)

        true
      end

      # Revoke a recovery token (delete from Redis)
      #
      # @param session_id [String] UUID of the onboarding session
      # @return [Boolean] True if token was deleted
      def revoke(session_id)
        redis_key = "#{REDIS_KEY_PREFIX}#{session_id}"
        redis.del(redis_key) > 0
      end

      private

      # Redis connection instance
      # Uses REDIS_URL environment variable or defaults to localhost
      #
      # @return [Redis] Redis connection
      def redis
        @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
      end
    end
  end
end
