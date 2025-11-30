# frozen_string_literal: true

module Types
  # GraphQL type for match score breakdown
  # Shows individual component scores that make up the overall match score
  #
  # Story 5.4: Matching Recommendations API
  class MatchScoreBreakdownType < Types::BaseObject
    description "Breakdown of match score components for transparency"

    field :specialization_score, Integer, null: false,
          description: "Specialization match score (0-100) - weighted 40%"

    field :age_range_score, Integer, null: false,
          description: "Age range fit score (0-100) - weighted 30%"

    field :availability_score, Integer, null: false,
          description: "Availability score (0-100) - weighted 20%"

    field :modality_score, Integer, null: false,
          description: "Treatment modality score (0-100) - weighted 10%"

    # Convert 0.0-1.0 component scores to 0-100 scale
    def specialization_score
      (object[:specialization] * 100).round
    end

    def age_range_score
      (object[:age_range] * 100).round
    end

    def availability_score
      (object[:availability] * 100).round
    end

    def modality_score
      (object[:treatment_modality] * 100).round
    end
  end
end
