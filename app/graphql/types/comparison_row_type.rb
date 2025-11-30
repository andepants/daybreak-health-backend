# frozen_string_literal: true

module Types
  # GraphQL type for comparison table row
  #
  # Represents a single row in the insurance vs. self-pay comparison table
  class ComparisonRowType < Types::BaseObject
    description "Comparison table row showing insurance vs. self-pay"

    field :label, String, null: false,
          description: "Row label (e.g., 'Per Session Cost')"

    field :insurance_value, String, null: true,
          description: "Insurance cost for this item (null if not applicable)"

    field :self_pay_value, String, null: false,
          description: "Self-pay cost for this item"

    field :highlight_self_pay, Boolean, null: false,
          description: "Whether to highlight self-pay as the better value for this row"
  end
end
