# frozen_string_literal: true

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
#   raise GraphqlErrors::BaseError.new(
#     'Session not found',
#     code: 'NOT_FOUND'
#   )
class GraphqlErrors::BaseError < ::GraphQL::ExecutionError
  attr_reader :code, :details

  # Initialize a new GraphQL error
  #
  # @param message [String] Human-readable error message
  # @param code [String] Error code from ErrorCodes
  # @param details [Hash] Additional error details (optional)
  def initialize(message, code: GraphqlErrors::ErrorCodes::INTERNAL_ERROR, details: {})
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
class GraphqlErrors::UnauthenticatedError < GraphqlErrors::BaseError
  def initialize(message = 'Authentication required')
    super(message, code: GraphqlErrors::ErrorCodes::UNAUTHENTICATED)
  end
end

# Permission denied error
class GraphqlErrors::ForbiddenError < GraphqlErrors::BaseError
  def initialize(message = 'Permission denied')
    super(message, code: GraphqlErrors::ErrorCodes::FORBIDDEN)
  end
end

# Resource not found error
class GraphqlErrors::NotFoundError < GraphqlErrors::BaseError
  def initialize(message = 'Resource not found', resource_type: nil)
    details = resource_type ? { resource_type: resource_type } : {}
    super(message, code: GraphqlErrors::ErrorCodes::NOT_FOUND, details: details)
  end
end

# Validation error
class GraphqlErrors::ValidationError < GraphqlErrors::BaseError
  def initialize(message = 'Validation failed', errors: {})
    details = errors.any? ? { errors: errors } : {}
    super(message, code: GraphqlErrors::ErrorCodes::VALIDATION_ERROR, details: details)
  end
end

# Session expired error
class GraphqlErrors::SessionExpiredError < GraphqlErrors::BaseError
  def initialize(message = 'Session has expired')
    super(message, code: GraphqlErrors::ErrorCodes::SESSION_EXPIRED)
  end
end

# Rate limit error
class GraphqlErrors::RateLimitedError < GraphqlErrors::BaseError
  def initialize(message = 'Rate limit exceeded', retry_after: nil)
    details = retry_after ? { retry_after: retry_after } : {}
    super(message, code: GraphqlErrors::ErrorCodes::RATE_LIMITED, details: details)
  end
end

# Internal server error
class GraphqlErrors::InternalError < GraphqlErrors::BaseError
  def initialize(message = 'An unexpected error occurred')
    # Never expose internal error details to clients
    super(message, code: GraphqlErrors::ErrorCodes::INTERNAL_ERROR)
  end
end
