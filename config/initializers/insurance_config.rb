# frozen_string_literal: true

# Insurance Configuration
# Loads known payers from config/known_payers.yml
# Configures support contacts, self-pay options, and insurance glossary

Rails.application.config.after_initialize do
  # Load known payers
  payers_file = Rails.root.join("config/known_payers.yml")

  if File.exist?(payers_file)
    payers_config = YAML.load_file(payers_file)
    Rails.application.config.known_payers = payers_config["payers"]
    Rails.application.config.known_payer_names = payers_config["payers"].map { |p| p["name"] }
  else
    Rails.logger.warn "Known payers configuration file not found at #{payers_file}"
    Rails.application.config.known_payers = []
    Rails.application.config.known_payer_names = []
  end

  # Load insurance glossary (Story 4.5)
  glossary_file = Rails.root.join("config/insurance_glossary.yml")

  if File.exist?(glossary_file)
    glossary_config = YAML.load_file(glossary_file)
    Rails.application.config.insurance_glossary = glossary_config["terms"]
  else
    Rails.logger.warn "Insurance glossary file not found at #{glossary_file}"
    Rails.application.config.insurance_glossary = {}
  end

  # Story 4.5: Support contact configuration
  # Different contacts based on error severity
  Rails.application.config.insurance_support_contacts = {
    general: {
      type: "general",
      phone: ENV.fetch("SUPPORT_PHONE_GENERAL", "1-800-DAYBREAK"),
      email: ENV.fetch("SUPPORT_EMAIL_GENERAL", "support@daybreak.health"),
      hours: "Mon-Sun 8am-8pm EST"
    },
    specialist: {
      type: "specialist",
      phone: ENV.fetch("SUPPORT_PHONE_INSURANCE", "1-800-DAYBREAK x2"),
      email: ENV.fetch("SUPPORT_EMAIL_INSURANCE", "insurance@daybreak.health"),
      hours: "Mon-Fri 8am-6pm EST"
    }
  }

  # Story 4.5: Self-pay option configuration
  # Preview rates shown to parents (full details in Story 4.6)
  Rails.application.config.self_pay_options = {
    description: "Continue with self-pay",
    preview_rate: "$150 for initial assessment",
    detailed_rates: {
      initial_assessment: 150,
      follow_up_session: 100,
      group_session: 50
    }
  }

  # Story 4.5: Maximum retry attempts for verification
  Rails.application.config.insurance_max_retry_attempts = 3
end
