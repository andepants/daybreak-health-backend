# frozen_string_literal: true

module Ai
  # Main AI client service with provider selection logic
  # Follows ADR-002: Agnostic AI Provider pattern
  #
  # Supports multiple AI providers (Anthropic, OpenAI) with
  # configuration-driven provider selection and fallback capability.
  #
  # Usage:
  #   client = Ai::Client.new
  #   response = client.chat(messages: messages, context: context)
  #
  # Or with specific provider:
  #   client = Ai::Client.new(provider: :openai)
  #   response = client.chat(messages: messages, context: context)
  class Client
    # Available provider implementations
    PROVIDERS = {
      anthropic: Providers::AnthropicProvider,
      openai: Providers::OpenaiProvider
    }.freeze

    # Default provider if not specified
    DEFAULT_PROVIDER = :anthropic

    attr_reader :provider

    # Initialize AI client with specified or default provider
    #
    # @param provider [Symbol, nil] Provider to use (:anthropic or :openai)
    # @raise [ArgumentError] If provider is not supported
    def initialize(provider: nil)
      provider_key = (provider || configured_provider || DEFAULT_PROVIDER).to_sym

      unless PROVIDERS.key?(provider_key)
        raise ArgumentError, "Unsupported provider: #{provider_key}. " \
                             "Supported providers: #{PROVIDERS.keys.join(', ')}"
      end

      @provider = PROVIDERS[provider_key].new
      @provider_name = provider_key
    end

    # Non-streaming chat completion
    # Delegates to configured provider
    #
    # @param messages [Array<Hash>] Array of message hashes with :role and :content
    # @param context [Hash] Additional context for the AI (session info, settings, etc.)
    # @return [Hash] Response with :content, :role, :model, and metadata
    def chat(messages:, context: {})
      validate_messages!(messages)

      @provider.chat(messages: messages, context: context)
    rescue Providers::BaseProvider::RateLimitError => e
      # Let Sidekiq handle retry with exponential backoff
      Rails.logger.warn("AI rate limit hit for provider #{@provider_name}: #{e.message}")
      raise
    rescue Providers::BaseProvider::AuthenticationError => e
      # Authentication errors should not be retried
      Rails.logger.error("AI authentication error for provider #{@provider_name}: #{e.message}")
      raise
    rescue Providers::BaseProvider::ApiError => e
      # General API errors
      Rails.logger.error("AI API error for provider #{@provider_name}: #{e.message}")
      raise
    end

    # Streaming chat completion
    # Delegates to configured provider and yields chunks as they arrive
    #
    # @param messages [Array<Hash>] Array of message hashes with :role and :content
    # @param context [Hash] Additional context for the AI (session info, settings, etc.)
    # @yield [String] Chunks of generated text as they arrive
    # @return [Hash] Final response with :content, :role, :model, and metadata
    def stream(messages:, context: {}, &block)
      validate_messages!(messages)

      @provider.stream(messages: messages, context: context, &block)
    rescue Providers::BaseProvider::RateLimitError => e
      # Let Sidekiq handle retry with exponential backoff
      Rails.logger.warn("AI rate limit hit for provider #{@provider_name}: #{e.message}")
      raise
    rescue Providers::BaseProvider::AuthenticationError => e
      # Authentication errors should not be retried
      Rails.logger.error("AI authentication error for provider #{@provider_name}: #{e.message}")
      raise
    rescue Providers::BaseProvider::ApiError => e
      # General API errors
      Rails.logger.error("AI API error for provider #{@provider_name}: #{e.message}")
      raise
    end

    # Get provider name for logging/debugging
    #
    # @return [Symbol] Provider name
    def provider_name
      @provider_name
    end

    private

    # Get configured provider from environment
    # Falls back to DEFAULT_PROVIDER if not configured
    #
    # @return [Symbol, nil] Configured provider or nil
    def configured_provider
      provider_env = ENV.fetch("AI_PROVIDER", nil)
      return nil if provider_env.blank?

      provider_env.to_sym
    end

    # Validate messages array format
    #
    # @param messages [Array<Hash>] Messages to validate
    # @raise [ArgumentError] If messages are invalid
    def validate_messages!(messages)
      raise ArgumentError, "Messages must be an array" unless messages.is_a?(Array)
      raise ArgumentError, "Messages cannot be empty" if messages.empty?

      messages.each_with_index do |msg, index|
        unless msg.is_a?(Hash) && msg.key?(:role) && msg.key?(:content)
          raise ArgumentError, "Message at index #{index} must have :role and :content keys"
        end

        unless %w[system user assistant].include?(msg[:role].to_s)
          raise ArgumentError, "Message at index #{index} has invalid role: #{msg[:role]}"
        end
      end
    end
  end
end
