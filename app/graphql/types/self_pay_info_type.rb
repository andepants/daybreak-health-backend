# frozen_string_literal: true

module Types
  class SelfPayInfoType < Types::BaseObject
    description "Self-pay pricing and assistance information"

    field :session_rate, String, null: false,
      description: "Formatted currency amount (e.g., '$150.00')"

    field :description, String, null: false,
      description: "Description of services covered"

    field :payment_deferred, Boolean, null: false,
      description: "Whether payment is deferred (true for MVP)"

    field :deferral_note, String, null: true,
      description: "Explanation of payment deferral"

    field :financial_assistance_available, Boolean, null: false,
      description: "Whether financial assistance info is shown"

    field :financial_assistance_info, String, null: true,
      description: "Financial assistance details if available"

    field :next_steps, [String], null: false,
      description: "What happens after selecting self-pay"
  end
end
