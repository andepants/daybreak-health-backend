# frozen_string_literal: true

module Errors
  # Base error class for GraphQL errors
  #
  # Provides standard error format with message and extensions.
  # All custom GraphQL errors should inherit from this class.
  #
  # Error format:
  #   {
  #     message: "Human-readable error message",
  #     extensions: {
  #       code: "ERROR_CODE",
  #       timestamp: "2025-11-29T10:00:00Z",
  #       path: ["mutation", "updateSession"]
  #     }
  #   }
  #
  # Example usage:
  #   raise Errors::BaseError.new(
  #     'Session not found',
  #     code: 'NOT_FOUND'
  #   )
  class BaseError < ::GraphQL::ExecutionError
    attr_reader :code, :details

    # Initialize a new GraphQL error
    #
    # @param message [String] Human-readable error message
    # @param code [String] Error code from ErrorCodes
    # @param details [Hash] Additional error details (optional)
    def initialize(message, code: ErrorCodes::INTERNAL_ERROR, details: {})
      @code = code
      @details = details

      # Ensure PHI-safe error messages
      sanitized_message = sanitize_message(message)

      super(
        sanitized_message,
        extensions: build_extensions
      )
    end

    # Build error extensions hash
    #
    # @return [Hash] Extensions with code, timestamp, and details
    def build_extensions
      {
        code: @code,
        timestamp: Time.current.iso8601,
        **@details
      }
    end

    private

    # Sanitize error message to ensure no PHI is leaked
    #
    # @param message [String] Original error message
    # @return [String] Sanitized message
    def sanitize_message(message)
      # In production, we might want to further sanitize messages
      # For now, just ensure it's a string and limit length
      message.to_s.truncate(500)
    end
  end

  # Specific error classes for common scenarios
  #
  # These provide convenient error constructors with appropriate codes

  # Authentication required error
  class UnauthenticatedError < BaseError
    def initialize(message = 'Authentication required')
      super(message, code: ErrorCodes::UNAUTHENTICATED)
    end
  end

  # Permission denied error
  class ForbiddenError < BaseError
    def initialize(message = 'Permission denied')
      super(message, code: ErrorCodes::FORBIDDEN)
    end
  end

  # Resource not found error
  class NotFoundError < BaseError
    def initialize(message = 'Resource not found', resource_type: nil)
      details = resource_type ? { resource_type: resource_type } : {}
      super(message, code: ErrorCodes::NOT_FOUND, details: details)
    end
  end

  # Validation error
  class ValidationError < BaseError
    def initialize(message = 'Validation failed', errors: {})
      details = errors.any? ? { errors: errors } : {}
      super(message, code: ErrorCodes::VALIDATION_ERROR, details: details)
    end
  end

  # Session expired error
  class SessionExpiredError < BaseError
    def initialize(message = 'Session has expired')
      super(message, code: ErrorCodes::SESSION_EXPIRED)
    end
  end

  # Rate limit error
  class RateLimitedError < BaseError
    def initialize(message = 'Rate limit exceeded', retry_after: nil)
      details = retry_after ? { retry_after: retry_after } : {}
      super(message, code: ErrorCodes::RATE_LIMITED, details: details)
    end
  end

  # Internal server error
  class InternalError < BaseError
    def initialize(message = 'An unexpected error occurred')
      # Never expose internal error details to clients
      super(message, code: ErrorCodes::INTERNAL_ERROR)
    end
  end
end
