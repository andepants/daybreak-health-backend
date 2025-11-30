# frozen_string_literal: true

module Types
  # GraphQL type for therapy session cost estimates
  #
  # Provides detailed cost breakdown showing what insurance will pay,
  # what the patient will pay, allowed vs billed amounts, and any
  # coverage limitations.
  #
  # All estimates include a disclaimer that they are not guarantees.
  #
  class CostEstimateType < Types::BaseObject
    description "Cost estimate for therapy session based on insurance coverage"

    field :insurance_pays, Float, null: false,
          description: "Estimated amount insurance will pay in USD"

    field :patient_pays, Float, null: false,
          description: "Estimated patient out-of-pocket responsibility in USD"

    field :allowed_amount, Float, null: false,
          description: "Allowed amount (contracted rate) for the service in USD"

    field :billed_amount, Float, null: false,
          description: "Provider's standard billed amount in USD"

    field :deductible_status, Types::DeductibleStatusType, null: false,
          description: "Current deductible status information"

    field :coverage_limitations, [ String ], null: false,
          description: "Array of limitation messages (session limits, prior auth, etc.)"

    field :is_estimate, Boolean, null: false,
          description: "Always true - indicates this is an estimate, not a guarantee"

    field :disclaimer, String, null: false,
          description: "Standard disclaimer text explaining this is an estimate only"

    field :calculated_at, GraphQL::Types::ISO8601DateTime, null: false,
          description: "When this estimate was calculated"
  end
end
