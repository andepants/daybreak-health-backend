# frozen_string_literal: true

module Types
  # GraphQL type for PaymentPlan model
  #
  # Represents a saved payment plan selection linked to an onboarding session.
  # Used in mutation responses and session queries.
  class PaymentPlanType < Types::BaseObject
    description "Payment plan selection for billing integration"

    field :id, ID, null: false,
          description: "Payment plan ID"

    field :plan_duration_months, Integer, null: false,
          description: "Plan duration in months (0 for upfront)"

    field :monthly_amount, Float, null: false,
          description: "Monthly payment amount in USD"

    field :total_amount, Float, null: false,
          description: "Total cost in USD"

    field :discount_applied, Float, null: false,
          description: "Discount amount applied in USD"

    field :payment_method_preference, Types::PaymentMethodEnum, null: false,
          description: "Preferred payment method"

    field :status, String, null: false,
          description: "Payment plan status (pending, active, completed, cancelled)"

    field :description, String, null: false,
          description: "Human-readable plan description"

    field :created_at, GraphQL::Types::ISO8601DateTime, null: false,
          description: "When the plan was created"

    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false,
          description: "When the plan was last updated"

    # Resolve payment method enum from string
    def payment_method_preference
      object.payment_method_preference.upcase
    end

    # Convert amounts to Float
    def monthly_amount
      object.monthly_amount.to_f
    end

    def total_amount
      object.total_amount.to_f
    end

    def discount_applied
      object.discount_applied.to_f
    end
  end
end
