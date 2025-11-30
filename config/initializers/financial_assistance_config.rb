# frozen_string_literal: true

# Load financial assistance configuration from config/financial_assistance.yml
#
# This initializer loads financial assistance eligibility rules and program
# information that are used by FinancialAssistanceType GraphQL type.
#
# Configuration includes:
# - Eligibility criteria
# - Income thresholds by household size
# - Sliding scale discount percentages
# - Application URL
# - Program description
#
# Available via: Rails.application.config.financial_assistance

config_file = Rails.root.join("config", "financial_assistance.yml")

if File.exist?(config_file)
  config = YAML.load_file(config_file, aliases: true)[Rails.env]

  if config
    Rails.application.config.financial_assistance = config.deep_symbolize_keys
    Rails.logger.info "Loaded financial assistance configuration for #{Rails.env} environment"
  else
    Rails.logger.warn "No financial assistance configuration found for #{Rails.env} environment"
    Rails.application.config.financial_assistance = nil
  end
else
  Rails.logger.warn "Financial assistance configuration file not found: #{config_file}"
  Rails.application.config.financial_assistance = nil
end
