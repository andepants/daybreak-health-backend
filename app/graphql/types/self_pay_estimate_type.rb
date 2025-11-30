# frozen_string_literal: true

module Types
  # GraphQL type for self-pay cost estimate
  #
  # Represents transparent self-pay pricing with options
  class SelfPayEstimateType < Types::BaseObject
    description "Self-pay cost estimate with transparent pricing"

    field :base_rate, String, null: false,
          description: "Base rate per session (e.g., '$50 per session')"

    field :total_for_typical_treatment, String, null: false,
          description: "Total cost for typical treatment (8-12 sessions)"

    field :sliding_scale_info, String, null: true,
          description: "Information about sliding scale discounts if available"

    field :package_options, [Types::PackageOptionType], null: false,
          description: "Package pricing options with savings"

    field :transparent_pricing_message, String, null: false,
          description: "No hidden fees message"

    field :what_is_included, [String], null: false,
          description: "Services included in the rate"

    field :what_is_not_included, [String], null: false,
          description: "Services not included in the rate"
  end
end
