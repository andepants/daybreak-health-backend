# frozen_string_literal: true

module Types
  # GraphQL type for payment plan option display
  #
  # Represents a single payment plan option (e.g., 3-month plan, upfront payment)
  # with calculated monthly amounts, total costs, and fee/interest disclosure.
  #
  # Used by paymentPlanOptions query to display available payment options to parents.
  class PaymentPlanOptionType < Types::BaseObject
    description "Payment plan option with cost breakdown"

    field :duration_months, Integer, null: false,
          description: "Plan duration in months (0 for upfront payment)"

    field :monthly_amount, Float, null: false,
          description: "Monthly payment amount in USD"

    field :total_amount, Float, null: false,
          description: "Total cost including any interest/fees in USD"

    field :interest_rate, Float, null: false,
          description: "Annual interest rate as percentage (e.g., 5.0 for 5%)"

    field :has_fees, Boolean, null: false,
          description: "Whether this plan has interest or service fees"

    field :fee_amount, Float, null: false,
          description: "Total fees/interest amount in USD"

    field :upfront_discount, Float, null: true,
          description: "Discount percentage for upfront payment (null for monthly plans)"

    field :description, String, null: false,
          description: "Human-readable plan description"

    # Convert BigDecimal to Float for GraphQL
    def monthly_amount
      object[:monthly_amount].to_f
    end

    def total_amount
      object[:total_amount].to_f
    end

    def fee_amount
      object[:fee_amount].to_f
    end
  end
end
