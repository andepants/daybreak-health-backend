# frozen_string_literal: true

module Support
  # Intercom integration service for customer support
  #
  # Provides identity verification for secure Intercom widget integration.
  # Uses HMAC-SHA256 to generate user identity hashes to prevent impersonation.
  #
  # HIPAA Compliance:
  # - Only session IDs and non-PHI metadata are passed to Intercom
  # - No names, DOB, medical information, or other PHI is transmitted
  # - Identity verification prevents unauthorized access to support conversations
  #
  # Configuration:
  # - INTERCOM_APP_ID: Intercom workspace app ID
  # - INTERCOM_SECRET_KEY: Secret key for identity verification (min 32 chars)
  # - INTERCOM_ENABLED: Enable/disable Intercom integration (default: false in test)
  #
  # Example usage:
  #   service = Support::IntercomService.new(session_id: '123')
  #   result = service.generate_identity
  #   # => {
  #   #   app_id: 'abc123',
  #   #   user_hash: 'hmac-sha256-hash',
  #   #   user_id: '123',
  #   #   enabled: true
  #   # }
  class IntercomService < BaseService
    attr_reader :session_id

    # Initialize the Intercom service
    #
    # @param session_id [String] The onboarding session ID to generate identity for
    # @raise [ArgumentError] If session_id is blank
    def initialize(session_id:)
      raise ArgumentError, 'session_id cannot be blank' if session_id.blank?

      @session_id = session_id
    end

    # Generate Intercom identity verification data
    #
    # Returns all data needed by the frontend to initialize Intercom widget
    # with secure JWT-based identity verification.
    #
    # @return [Hash] Identity verification data
    #   - app_id [String] Intercom app ID
    #   - user_jwt [String] JWT token for identity verification
    #   - user_id [String] The session ID (used as Intercom user identifier)
    #   - enabled [Boolean] Whether Intercom is enabled
    #
    # @example
    #   service = Support::IntercomService.new(session_id: 'abc-123')
    #   identity = service.generate_identity
    #   # => { app_id: '...', user_jwt: '...', user_id: 'abc-123', enabled: true }
    def call
      {
        app_id: app_id,
        user_jwt: generate_user_jwt,
        user_id: session_id,
        enabled: intercom_enabled?
      }
    end

    # Class method convenience wrapper
    #
    # @param session_id [String] The onboarding session ID
    # @return [Hash] Identity verification data
    #
    # @example
    #   Support::IntercomService.call(session_id: '123')
    def self.call(session_id:)
      new(session_id: session_id).call
    end

    private

    # Generate JWT for Intercom identity verification
    #
    # Creates a signed JWT containing the user ID for secure identity verification.
    # This prevents user impersonation by ensuring only the server can generate valid tokens.
    #
    # @return [String, nil] Signed JWT token or nil if not enabled
    def generate_user_jwt
      return nil unless intercom_enabled?

      key = secret_key
      return nil if key.nil?

      payload = {
        user_id: session_id,
        iat: Time.now.to_i,
        exp: 1.hour.from_now.to_i
      }

      JWT.encode(payload, key, 'HS256')
    end

    # Get Intercom app ID from environment
    #
    # @return [String, nil] App ID or nil if not configured
    def app_id
      ENV['INTERCOM_APP_ID']
    end

    # Get Intercom secret key from environment
    #
    # Validates secret key format to ensure it meets security requirements:
    # - Minimum 32 characters
    # - Alphanumeric and base64-safe characters only (a-z, A-Z, 0-9, +, /, =, -, _)
    #
    # @return [String, nil] Secret key or nil if not configured properly
    def secret_key
      key = ENV['INTERCOM_SECRET_KEY']

      return nil if key.blank?
      return nil if key.length < 32

      # Validate format: alphanumeric and base64-safe characters only
      # Allowed: a-z, A-Z, 0-9, +, /, =, -, _
      unless key.match?(/\A[A-Za-z0-9+\/=\-_]+\z/)
        Rails.logger.error('[Intercom] INTERCOM_SECRET_KEY contains invalid characters - ' \
                           'must be alphanumeric or base64-safe characters only')
        return nil
      end

      key
    end

    # Check if Intercom is enabled
    #
    # Intercom is disabled by default in test environment.
    # Can be explicitly enabled/disabled via INTERCOM_ENABLED env var.
    #
    # @return [Boolean] true if Intercom is enabled and configured
    def intercom_enabled?
      return false if Rails.env.test? && ENV['INTERCOM_ENABLED'] != 'true'

      app_id.present? && secret_key.present?
    end
  end
end
