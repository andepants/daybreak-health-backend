# frozen_string_literal: true

module Errors
  # Standard error codes for GraphQL API
  #
  # These codes align with the Architecture document's error handling specification.
  # All GraphQL errors should use these standard codes for consistency.
  #
  # Example usage:
  #   raise GraphQL::ExecutionError.new(
  #     'User not authenticated',
  #     extensions: { code: Errors::ErrorCodes::UNAUTHENTICATED }
  #   )
  module ErrorCodes
    # User is not authenticated (401 equivalent)
    UNAUTHENTICATED = 'UNAUTHENTICATED'

    # User lacks permission for this action (403 equivalent)
    FORBIDDEN = 'FORBIDDEN'

    # Requested resource does not exist (404 equivalent)
    NOT_FOUND = 'NOT_FOUND'

    # Input validation failed (400 equivalent)
    VALIDATION_ERROR = 'VALIDATION_ERROR'

    # Session has expired (401 equivalent)
    SESSION_EXPIRED = 'SESSION_EXPIRED'

    # Session has been abandoned (400 equivalent)
    # AC 2.5.6: Abandoned session cannot be resumed
    SESSION_ABANDONED = 'SESSION_ABANDONED'

    # Rate limit exceeded (429 equivalent)
    RATE_LIMITED = 'RATE_LIMITED'

    # Internal server error (500 equivalent)
    INTERNAL_ERROR = 'INTERNAL_ERROR'

    # Business logic conflict (409 equivalent)
    CONFLICT = 'CONFLICT'

    # External service unavailable (503 equivalent)
    SERVICE_UNAVAILABLE = 'SERVICE_UNAVAILABLE'

    # All valid error codes (for validation)
    ALL_CODES = [
      UNAUTHENTICATED,
      FORBIDDEN,
      NOT_FOUND,
      VALIDATION_ERROR,
      SESSION_EXPIRED,
      SESSION_ABANDONED,
      RATE_LIMITED,
      INTERNAL_ERROR,
      CONFLICT,
      SERVICE_UNAVAILABLE
    ].freeze

    # Check if a code is valid
    #
    # @param code [String] Error code to check
    # @return [Boolean] true if code is valid
    def self.valid?(code)
      ALL_CODES.include?(code)
    end
  end
end
