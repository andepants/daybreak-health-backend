# frozen_string_literal: true

module Types
  # GraphQL type for individual cost adjustments
  #
  # Represents a line item adjustment in cost calculation breakdown.
  # Adjustments can be positive (fees, taxes) or negative (discounts).
  #
  # Example adjustments:
  # - Duration modifier: +$30 for 90-minute session
  # - Therapist tier: +$30 for senior clinician
  # - Tax: +$13.50 (7.5% of subtotal)
  # - Discount: -$15 (promotional code)
  class CostAdjustmentType < Types::BaseObject
    description "A cost adjustment line item (fee, modifier, tax, or discount)"

    field :type, String, null: false,
          description: "Adjustment type (duration_modifier, therapist_tier, special_service, tax, discount)"

    field :description, String, null: false,
          description: "Human-readable description of the adjustment"

    field :amount, Float, null: false,
          description: "Dollar amount of adjustment (positive for fees, negative for discounts)"

    field :percentage, Float, null: true,
          description: "Percentage value if adjustment is percentage-based (e.g., 20 for 20%)"
  end
end
