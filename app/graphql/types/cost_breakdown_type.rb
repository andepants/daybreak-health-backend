# frozen_string_literal: true

module Types
  # GraphQL type for cost calculation breakdown
  #
  # Represents the complete cost calculation for a therapy session,
  # including base cost, all adjustments, and final cost.
  #
  # Used by:
  # - calculateCost query (real-time calculation)
  # - OnboardingSession.costEstimate field (stored calculation)
  #
  # Example breakdown:
  #   {
  #     grossCost: 150.00,
  #     adjustments: [
  #       { type: 'duration_modifier', description: '90 minutes', amount: 60.00 },
  #       { type: 'discount', description: '10% off', amount: -21.00 }
  #     ],
  #     netCost: 189.00,
  #     currency: 'USD',
  #     calculatedAt: '2025-11-30T12:00:00Z'
  #   }
  class CostBreakdownType < Types::BaseObject
    description "Cost calculation breakdown for a therapy session"

    field :gross_cost, Float, null: false,
          description: "Base cost before any adjustments",
          method: :gross_cost

    field :net_cost, Float, null: false,
          description: "Final cost after all adjustments",
          method: :net_cost

    field :adjustments, [ Types::CostAdjustmentType ], null: false,
          description: "Array of cost adjustments (fees, modifiers, taxes, discounts)"

    field :currency, String, null: false,
          description: "Currency code (e.g., USD)"

    field :calculated_at, GraphQL::Types::ISO8601DateTime, null: false,
          description: "Timestamp when calculation was performed",
          method: :calculated_at

    field :metadata, GraphQL::Types::JSON, null: true,
          description: "Additional calculation metadata (service_type, duration, etc.)"

    field :discount_code_invalid, Boolean, null: true,
          description: "Whether the provided discount code was invalid (for user feedback)"

    # Resolve adjustments as structured objects
    def adjustments
      return [] unless object[:adjustments]

      object[:adjustments].map do |adj|
        # Convert hash keys to symbols if needed
        adj.is_a?(Hash) ? adj.symbolize_keys : adj
      end
    end

    # Parse calculated_at timestamp
    def calculated_at
      timestamp = object[:calculated_at] || object["calculated_at"]
      return Time.current unless timestamp

      Time.parse(timestamp)
    rescue ArgumentError
      Time.current
    end
  end
end
