# frozen_string_literal: true

# AI Provider Configuration
# Configures AI service providers for conversational intake
#
# Environment Variables:
#   AI_PROVIDER - 'anthropic' (default) or 'openai'
#   ANTHROPIC_API_KEY - API key for Anthropic Claude
#   OPENAI_API_KEY - API key for OpenAI GPT
#
# Provider Selection:
#   The AI_PROVIDER environment variable determines which provider is used.
#   If not set, defaults to 'anthropic' as primary provider.
#
# Sidekiq Retry Configuration:
#   Rate limit errors trigger exponential backoff with following schedule:
#   - Retry 1: 30 seconds
#   - Retry 2: 1 minute
#   - Retry 3: 5 minutes
#   - Retry 4: 15 minutes
#   - Retry 5: 30 minutes
#   Maximum 5 retries before giving up

Rails.application.config.after_initialize do
  # Log configured AI provider
  provider = ENV.fetch("AI_PROVIDER", "anthropic")
  Rails.logger.info("AI Provider configured: #{provider}")

  # Validate API keys are present (warn if missing, don't fail app boot)
  case provider
  when "anthropic"
    if ENV["ANTHROPIC_API_KEY"].blank?
      Rails.logger.warn("ANTHROPIC_API_KEY not configured - AI features will not work")
    end
  when "openai"
    if ENV["OPENAI_API_KEY"].blank?
      Rails.logger.warn("OPENAI_API_KEY not configured - AI features will not work")
    end
  else
    Rails.logger.warn("Unknown AI_PROVIDER: #{provider}. Supported: anthropic, openai")
  end
end

# Sidekiq retry configuration for AI provider rate limiting
# This will be used by any job that calls AI services
#
# Usage in job class:
#   sidekiq_options retry: 5
#   sidekiq_retry_in do |count, exception|
#     case exception
#     when Ai::Providers::BaseProvider::RateLimitError
#       AI_RATE_LIMIT_RETRY_SCHEDULE[count] || 1800 # 30 minutes max
#     else
#       nil # Use default Sidekiq retry schedule
#     end
#   end
AI_RATE_LIMIT_RETRY_SCHEDULE = [
  30,    # Retry 1: 30 seconds
  60,    # Retry 2: 1 minute
  300,   # Retry 3: 5 minutes
  900,   # Retry 4: 15 minutes
  1800   # Retry 5: 30 minutes
].freeze
