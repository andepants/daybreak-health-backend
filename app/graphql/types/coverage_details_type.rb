# frozen_string_literal: true

module Types
  # GraphQL type for insurance coverage details
  #
  # Displays coverage information for verified insurance plans in user-friendly format.
  # Used by InsuranceType to show coverage details to parents.
  class CoverageDetailsType < Types::BaseObject
    description "Insurance coverage details for verified plans"

    field :copay_amount, String, null: true,
          description: "Copay amount formatted as currency, e.g., '$25 per visit'"

    field :services_covered, [String], null: false,
          description: "List of covered services"

    field :effective_date, String, null: true,
          description: "Coverage effective date"

    field :deductible, String, null: true,
          description: "Deductible amount with met status, e.g., '$500 ($100 met)'"

    field :coinsurance, Integer, null: true,
          description: "Coinsurance percentage, e.g., 20 for 20%"
  end
end
