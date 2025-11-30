# frozen_string_literal: true

module Types
  # GraphQL type for match reason explaining why a therapist was recommended
  #
  # Story 5.1: Therapist Matching Results Display
  # Part of the matching results API response
  class MatchReasonType < Types::BaseObject
    description "A reason explaining why a therapist was matched"

    field :id, String, null: false,
          description: "Reason identifier (e.g., 'specialty_match', 'availability')"

    field :text, String, null: false,
          description: "Human-readable reason text"

    field :icon, String, null: true,
          description: "Optional icon identifier for UI display"
  end
end
