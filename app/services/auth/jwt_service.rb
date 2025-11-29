# frozen_string_literal: true

module Auth
  # JWT encoding and decoding service
  #
  # Handles creation and validation of JSON Web Tokens for authentication.
  # Uses HS256 algorithm with 1-hour token expiration.
  #
  # Security constraints:
  # - JWT secret must be >= 32 characters
  # - Tokens expire after 1 hour
  # - All tokens include iat (issued at) and exp (expiration) claims
  #
  # Example usage:
  #   # Encode
  #   token = Auth::JwtService.encode(session_id: '123', role: 'parent')
  #
  #   # Decode
  #   payload = Auth::JwtService.decode(token)
  #   # => { session_id: '123', role: 'parent', exp: ..., iat: ... }
  #
  #   # Handle expiration
  #   payload = Auth::JwtService.decode(expired_token)
  #   # => nil (logs warning)
  class JwtService
    ALGORITHM = 'HS256'
    DEFAULT_EXPIRATION = 1.hour

    class << self
      # Encode a payload into a JWT token
      #
      # @param payload [Hash] Data to encode in the token
      # @param exp [Time] Token expiration time (default: 1 hour from now)
      # @return [String] Encoded JWT token
      #
      # @example
      #   token = Auth::JwtService.encode(
      #     session_id: session.id,
      #     role: 'parent'
      #   )
      def encode(payload, exp: DEFAULT_EXPIRATION.from_now)
        raise ArgumentError, 'Payload must be a Hash' unless payload.is_a?(Hash)

        payload = payload.dup
        payload[:exp] = exp.to_i
        payload[:iat] = Time.current.to_i

        JWT.encode(payload, secret, ALGORITHM)
      end

      # Decode a JWT token and return the payload
      #
      # @param token [String] JWT token to decode
      # @return [ActiveSupport::HashWithIndifferentAccess, nil] Decoded payload or nil if invalid
      #
      # @example
      #   payload = Auth::JwtService.decode(token)
      #   session_id = payload[:session_id]
      def decode(token)
        return nil if token.blank?

        decoded = JWT.decode(token, secret, true, algorithm: ALGORITHM)
        HashWithIndifferentAccess.new(decoded.first)
      rescue JWT::ExpiredSignature => e
        Rails.logger.warn("JWT expired: #{e.message}")
        nil
      rescue JWT::DecodeError => e
        Rails.logger.warn("JWT decode failed: #{e.message}")
        nil
      end

      # Validate that a token is well-formed and not expired
      #
      # @param token [String] JWT token to validate
      # @return [Boolean] true if token is valid
      def valid?(token)
        decode(token).present?
      end

      private

      # Get JWT secret from Rails credentials
      # Falls back to environment variable for development/test
      #
      # @return [String] JWT secret key
      # @raise [KeyError] If secret is not configured
      def secret
        @secret ||= begin
          if Rails.env.production?
            Rails.application.credentials.jwt_secret!
          else
            ENV.fetch('JWT_SECRET') do
              Rails.application.credentials.dig(:jwt_secret) ||
                'development-secret-key-min-32-chars-long-change-in-production'
            end
          end
        end

        validate_secret!
        @secret
      end

      # Validate that the secret meets minimum security requirements
      #
      # @raise [ArgumentError] If secret is too short
      def validate_secret!
        if @secret.length < 32
          raise ArgumentError, 'JWT secret must be at least 32 characters long'
        end
      end
    end
  end
end
