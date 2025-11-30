# frozen_string_literal: true

# Load payment plan configuration from config/payment_plans.yml
#
# This initializer loads payment plan settings that are used by
# Billing::PaymentPlanService to calculate payment plan options.
#
# Configuration includes:
# - Plan durations (3, 6, 12 months)
# - Upfront payment discount percentage
# - Interest rates by plan duration
# - Service fees by plan duration
#
# Available via: Rails.application.config.payment_plans

config_file = Rails.root.join("config", "payment_plans.yml")

if File.exist?(config_file)
  config = YAML.load_file(config_file, aliases: true)[Rails.env]

  if config
    Rails.application.config.payment_plans = config.deep_symbolize_keys
    Rails.logger.info "Loaded payment plan configuration for #{Rails.env} environment"
  else
    Rails.logger.warn "No payment plan configuration found for #{Rails.env} environment"
    Rails.application.config.payment_plans = nil
  end
else
  Rails.logger.warn "Payment plan configuration file not found: #{config_file}"
  Rails.application.config.payment_plans = nil
end
