# frozen_string_literal: true

module Ai
  module Providers
    # OpenAI GPT provider implementation
    # Backup AI provider for conversational intake
    #
    # Uses the ruby-openai gem for API communication
    # Handles OpenAI-specific message formatting and API interactions
    class OpenaiProvider < BaseProvider
      # Default model for intake conversations
      DEFAULT_MODEL = "gpt-4-turbo-preview"

      # Default max tokens for response
      DEFAULT_MAX_TOKENS = 1024

      # Default temperature for response generation (0.0-2.0)
      DEFAULT_TEMPERATURE = 0.7

      # Initialize OpenAI provider with API key from environment
      def initialize
        @client = OpenAI::Client.new(access_token: api_key)
      end

      # Non-streaming chat completion using GPT
      #
      # @param messages [Array<Hash>] Array of message hashes with :role and :content
      # @param context [Hash] Additional context with optional :model, :max_tokens, :temperature
      # @return [Hash] Response with :content, :role, :model, :usage
      def chat(messages:, context: {})
        start_time = Time.current

        begin
          formatted_messages = format_messages(messages)

          response = @client.chat(
            parameters: {
              model: context[:model] || DEFAULT_MODEL,
              max_tokens: context[:max_tokens] || DEFAULT_MAX_TOKENS,
              temperature: context[:temperature] || DEFAULT_TEMPERATURE,
              messages: formatted_messages
            }
          )

          duration = Time.current - start_time
          log_api_call(provider_name: "openai", message_count: messages.length, duration: duration)

          parse_response(response)
        rescue Faraday::TooManyRequestsError => e
          handle_rate_limit(e)
        rescue Faraday::UnauthorizedError => e
          handle_authentication_error(e)
        rescue Faraday::Error => e
          handle_api_error(e)
        end
      end

      # Streaming chat completion using GPT
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

          @client.chat(
            parameters: {
              model: context[:model] || DEFAULT_MODEL,
              max_tokens: context[:max_tokens] || DEFAULT_MAX_TOKENS,
              temperature: context[:temperature] || DEFAULT_TEMPERATURE,
              messages: formatted_messages,
              stream: proc { |chunk, _bytesize|
                content = chunk.dig("choices", 0, "delta", "content")
                if content
                  full_content += content
                  block.call(content) if block_given?
                end
              }
            }
          )

          duration = Time.current - start_time
          log_api_call(provider_name: "openai_stream", message_count: messages.length, duration: duration)

          {
            content: full_content,
            role: "assistant",
            model: context[:model] || DEFAULT_MODEL,
            provider: "openai"
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

      # Get OpenAI API key from environment
      # @return [String] API key
      # @raise [AuthenticationError] If API key is not configured
      def api_key
        key = ENV.fetch("OPENAI_API_KEY", nil)
        raise AuthenticationError, "OPENAI_API_KEY not configured" if key.blank?

        key
      end

      # Format messages for OpenAI API
      # OpenAI supports system, user, and assistant roles
      #
      # @param messages [Array<Hash>] Messages with :role and :content
      # @return [Array<Hash>] Formatted messages for OpenAI API
      def format_messages(messages)
        messages.map do |msg|
          {
            role: map_role(msg[:role]),
            content: msg[:content]
          }
        end
      end

      # Map role to OpenAI-compatible role
      # OpenAI supports 'system', 'user', and 'assistant'
      #
      # @param role [String, Symbol] Original role
      # @return [String] Mapped role
      def map_role(role)
        case role.to_s
        when "system" then "system"
        when "user" then "user"
        when "assistant" then "assistant"
        else "user" # Default to user for any other role
        end
      end

      # Parse OpenAI API response into standardized format
      #
      # @param response [Hash] Raw OpenAI API response
      # @return [Hash] Standardized response with :content, :role, :model, :usage
      def parse_response(response)
        choice = response.dig("choices", 0)
        content = choice.dig("message", "content") || ""

        {
          content: content,
          role: "assistant",
          model: response["model"],
          usage: {
            input_tokens: response.dig("usage", "prompt_tokens"),
            output_tokens: response.dig("usage", "completion_tokens"),
            total_tokens: response.dig("usage", "total_tokens")
          },
          provider: "openai"
        }
      end
    end
  end
end
