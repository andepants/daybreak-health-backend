# frozen_string_literal: true

# Session rates configuration loader
#
# Story 6.4: Deductible & Out-of-Pocket Tracking
# Loads session rate configuration for deductible projection calculations
#
Rails.application.config.to_prepare do
  session_rates_file = Rails.root.join("config/session_rates.yml")

  if File.exist?(session_rates_file)
    config = YAML.load_file(session_rates_file)
    Rails.application.config.session_rates = config["rates"] || {}
    Rails.application.config.default_session_type = config["default"] || "individual_therapy"

    Rails.logger.info("Session rates loaded: #{Rails.application.config.session_rates.keys.join(', ')}")
  else
    Rails.logger.warn("Session rates configuration not found at #{session_rates_file}")
    Rails.application.config.session_rates = {
      "intake" => 150.00,
      "individual_therapy" => 100.00,
      "family_therapy" => 125.00
    }
    Rails.application.config.default_session_type = "individual_therapy"
  end
end
