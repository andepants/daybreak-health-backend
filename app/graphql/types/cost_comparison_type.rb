# frozen_string_literal: true

module Types
  # GraphQL type for cost comparison between insurance and self-pay
  #
  # Provides comprehensive comparison data to help parents choose
  # between insurance and self-pay options.
  class CostComparisonType < Types::BaseObject
    description "Cost comparison between insurance and self-pay options"

    field :insurance_estimate, Types::InsuranceEstimateType, null: true,
          description: "Insurance cost estimate (null if insurance not verified)"

    field :self_pay_estimate, Types::SelfPayEstimateType, null: false,
          description: "Self-pay cost estimate (always available)"

    field :comparison_table, [ Types::ComparisonRowType ], null: false,
          description: "Side-by-side comparison rows"

    field :recommendation, String, null: true,
          description: "Personalized recommendation based on situation"

    field :savings_if_self_pay, Float, null: true,
          description: "Positive amount if self-pay is cheaper"

    field :highlight_self_pay, Boolean, null: false,
          description: "True when self-pay is the better option"
  end
end
