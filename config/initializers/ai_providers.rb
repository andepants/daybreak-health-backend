# AI Provider Configuration
# Configures OpenAI (primary) and Anthropic Claude (backup) providers for conversational AI
# Full implementation in Epic 3

# AI provider selection from environment
# Default: OpenAI (primary), Anthropic Claude available as backup
Rails.application.config.ai_provider = ENV.fetch("AI_PROVIDER", "openai")

# Validate provider is supported
unless %w[openai anthropic].include?(Rails.application.config.ai_provider)
  Rails.logger.warn "Unknown AI_PROVIDER: #{Rails.application.config.ai_provider}. Defaulting to 'openai'"
  Rails.application.config.ai_provider = "openai"
end

Rails.logger.info "AI Provider configured: #{Rails.application.config.ai_provider}"
