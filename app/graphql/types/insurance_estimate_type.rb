# frozen_string_literal: true

module Types
  # GraphQL type for insurance cost estimate
  #
  # Represents estimated costs when using insurance coverage
  class InsuranceEstimateType < Types::BaseObject
    description "Insurance-based cost estimate"

    field :per_session_cost, String, null: false,
          description: "Estimated cost per session"

    field :total_estimated_cost, String, null: false,
          description: "Total estimated cost for typical treatment"

    field :explanation, String, null: false,
          description: "Explanation of the estimate"

    field :assumption_notes, [String], null: false,
          description: "Important assumptions and disclaimers"
  end
end
