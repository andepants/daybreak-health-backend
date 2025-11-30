# frozen_string_literal: true

module Ai
  module Providers
    # Anthropic Claude AI provider implementation
    # Primary AI provider for conversational intake
    #
    # Uses the anthropic gem for API communication
    # Handles Claude-specific message formatting and API interactions
    class AnthropicProvider < BaseProvider
      # Default model for intake conversations
      DEFAULT_MODEL = "claude-3-5-sonnet-20241022"

      # Default max tokens for response
      DEFAULT_MAX_TOKENS = 1024

      # Default temperature for response generation (0.0-1.0)
      DEFAULT_TEMPERATURE = 0.7

      # Initialize Anthropic provider with API key from environment
      def initialize
        @client = Anthropic::Client.new(access_token: api_key)
      end

      # Non-streaming chat completion using Claude
      #
      # @param messages [Array<Hash>] Array of message hashes with :role and :content
      # @param context [Hash] Additional context with optional :model, :max_tokens, :temperature
      # @return [Hash] Response with :content, :role, :model, :usage
      def chat(messages:, context: {})
        start_time = Time.current

        begin
          formatted_messages = format_messages(messages)
          system_message = extract_system_message(messages)

          response = @client.messages(
            parameters: {
              model: context[:model] || DEFAULT_MODEL,
              max_tokens: context[:max_tokens] || DEFAULT_MAX_TOKENS,
              temperature: context[:temperature] || DEFAULT_TEMPERATURE,
              system: system_message,
              messages: formatted_messages
            }
          )

          duration = Time.current - start_time
          log_api_call(provider_name: "anthropic", message_count: messages.length, duration: duration)

          parse_response(response)
        rescue Faraday::TooManyRequestsError => e
          handle_rate_limit(e)
        rescue Faraday::UnauthorizedError => e
          handle_authentication_error(e)
        rescue Faraday::Error => e
          handle_api_error(e)
        end
      end

      # Streaming chat completion using Claude
      #
      # @param messages [Array<Hash>] Array of message hashes with :role and :content
      # @param context [Hash] Additional context with optional :model, :max_tokens, :temperature
      # @yield [String] Chunks of generated text as they arrive
      # @return [Hash] Final response with :content, :role, :model
      def stream(messages:, context: {}, &block)
        start_time = Time.current
        full_content = ""

        begin
          formatted_messages = format_messages(messages)
          system_message = extract_system_message(messages)

          @client.messages(
            parameters: {
              model: context[:model] || DEFAULT_MODEL,
              max_tokens: context[:max_tokens] || DEFAULT_MAX_TOKENS,
              temperature: context[:temperature] || DEFAULT_TEMPERATURE,
              system: system_message,
              messages: formatted_messages,
              stream: true
            }
          ) do |event|
            next unless event["type"] == "content_block_delta"
            next unless event.dig("delta", "type") == "text_delta"

            chunk = event.dig("delta", "text")
            if chunk
              full_content += chunk
              block.call(chunk) if block_given?
            end
          end

          duration = Time.current - start_time
          log_api_call(provider_name: "anthropic_stream", message_count: messages.length, duration: duration)

          {
            content: full_content,
            role: "assistant",
            model: context[:model] || DEFAULT_MODEL,
            provider: "anthropic"
          }
        rescue Faraday::TooManyRequestsError => e
          handle_rate_limit(e)
        rescue Faraday::UnauthorizedError => e
          handle_authentication_error(e)
        rescue Faraday::Error => e
          handle_api_error(e)
        end
      end

      private

      # Get Anthropic API key from environment
      # @return [String] API key
      # @raise [AuthenticationError] If API key is not configured
      def api_key
        key = ENV.fetch("ANTHROPIC_API_KEY", nil)
        raise AuthenticationError, "ANTHROPIC_API_KEY not configured" if key.blank?

        key
      end

      # Format messages for Anthropic API
      # Filters out system messages (handled separately) and ensures alternating user/assistant
      #
      # @param messages [Array<Hash>] Messages with :role and :content
      # @return [Array<Hash>] Formatted messages for Anthropic API
      def format_messages(messages)
        messages
          .reject { |msg| msg[:role].to_s == "system" }
          .map do |msg|
            {
              role: map_role(msg[:role]),
              content: msg[:content]
            }
          end
      end

      # Extract system message from messages array
      # Anthropic handles system messages separately from conversation messages
      #
      # @param messages [Array<Hash>] Messages with :role and :content
      # @return [String, nil] System message content or nil
      def extract_system_message(messages)
        system_msg = messages.find { |msg| msg[:role].to_s == "system" }
        system_msg&.fetch(:content, nil)
      end

      # Map role to Anthropic-compatible role
      # Anthropic only supports 'user' and 'assistant' in messages
      #
      # @param role [String, Symbol] Original role
      # @return [String] Mapped role
      def map_role(role)
        case role.to_s
        when "user" then "user"
        when "assistant" then "assistant"
        else "user" # Default to user for any other role
        end
      end

      # Parse Anthropic API response into standardized format
      #
      # @param response [Hash] Raw Anthropic API response
      # @return [Hash] Standardized response with :content, :role, :model, :usage
      def parse_response(response)
        content = response.dig("content", 0, "text") || ""

        {
          content: content,
          role: "assistant",
          model: response["model"],
          usage: {
            input_tokens: response.dig("usage", "input_tokens"),
            output_tokens: response.dig("usage", "output_tokens")
          },
          provider: "anthropic"
        }
      end
    end
  end
end
