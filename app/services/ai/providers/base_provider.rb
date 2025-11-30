# frozen_string_literal: true

module Ai
  module Providers
    # Abstract base class for AI provider implementations
    # Ensures consistent interface across all AI providers (Anthropic, OpenAI, future providers)
    #
    # This follows ADR-002: Agnostic AI Provider pattern for vendor flexibility
    #
    # All provider implementations must:
    # - Implement #chat for non-streaming responses
    # - Implement #stream for streaming responses
    # - Handle rate limiting with proper error classes
    # - Format messages to provider-specific format
    #
    # @abstract Subclass and implement abstract methods
    class BaseProvider
      # Error raised when API rate limit is hit
      # Will be caught by Sidekiq retry mechanism
      class RateLimitError < StandardError; end

      # Error raised when API request fails
      class ApiError < StandardError; end

      # Error raised when API authentication fails
      class AuthenticationError < StandardError; end

      # Non-streaming chat completion
      # Returns complete response after full generation
      #
      # @param messages [Array<Hash>] Array of message hashes with :role and :content
      # @param context [Hash] Additional context (session info, settings, etc.)
      # @return [Hash] Response with :content, :role, and metadata
      # @raise [NotImplementedError] Must be implemented by subclass
      def chat(messages:, context: {})
        raise NotImplementedError, "#{self.class} must implement #chat"
      end

      # Streaming chat completion
      # Yields chunks as they are generated
      #
      # @param messages [Array<Hash>] Array of message hashes with :role and :content
      # @param context [Hash] Additional context (session info, settings, etc.)
      # @yield [String] Chunks of generated text as they arrive
      # @return [Hash] Final response with :content, :role, and metadata
      # @raise [NotImplementedError] Must be implemented by subclass
      def stream(messages:, context: {}, &block)
        raise NotImplementedError, "#{self.class} must implement #stream"
      end

      protected

      # Handle rate limit errors consistently across providers
      # Raises RateLimitError which will trigger Sidekiq exponential backoff
      #
      # @param error [Exception] The original error from provider SDK
      # @raise [RateLimitError] Wrapped rate limit error
      def handle_rate_limit(error)
        raise RateLimitError, "Rate limit exceeded: #{error.message}"
      end

      # Handle authentication errors consistently across providers
      #
      # @param error [Exception] The original error from provider SDK
      # @raise [AuthenticationError] Wrapped authentication error
      def handle_authentication_error(error)
        raise AuthenticationError, "Authentication failed: #{error.message}"
      end

      # Handle general API errors consistently across providers
      #
      # @param error [Exception] The original error from provider SDK
      # @raise [ApiError] Wrapped API error
      def handle_api_error(error)
        raise ApiError, "API error: #{error.message}"
      end

      # Log API call for monitoring and debugging
      # Never logs actual message content (PHI-safe)
      #
      # @param provider_name [String] Name of the provider
      # @param message_count [Integer] Number of messages in context
      # @param duration [Float] Time taken for API call in seconds
      def log_api_call(provider_name:, message_count:, duration:)
        log_data = {
          provider: provider_name,
          message_count: message_count,
          duration_seconds: duration.round(3),
          timestamp: Time.current.iso8601
        }
        Rails.logger.info("AI API Call: #{log_data.to_json}")
      end
    end
  end
end
