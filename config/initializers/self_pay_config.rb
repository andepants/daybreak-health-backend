# frozen_string_literal: true

# Self-Pay Configuration
# Pricing and assistance information for parents choosing self-pay option
Rails.application.configure do
  config.self_pay = {
    rates: {
      initial_assessment: {
        amount_cents: 15_000, # $150.00
        description: "Initial comprehensive assessment (60-90 minutes)",
        services_included: [
          "Full clinical assessment",
          "Treatment recommendations",
          "Care plan development",
          "Follow-up coordination"
        ]
      },
      therapy_session: {
        amount_cents: 12_000, # $120.00
        description: "Individual therapy session (45-60 minutes)"
      }
    },
    financial_assistance: {
      enabled: true,
      contact: {
        phone: "1-800-DAYBREAK",
        email: "financial-assistance@daybreak.health",
        description: "Our team can discuss payment plans and sliding scale options"
      }
    },
    messaging: {
      option_title: "Continue with Self-Pay",
      option_description: "Get started immediately with transparent pricing and flexible payment options",
      payment_deferral_note: "No payment required today. We'll work with you on payment after your initial assessment."
    }
  }
end
