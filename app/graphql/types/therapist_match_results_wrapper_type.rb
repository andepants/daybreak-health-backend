# frozen_string_literal: true

module Types
  # GraphQL wrapper type for therapist matching results
  # Contains list of matched therapists with metadata
  #
  # Story 5.1: Therapist Matching Results Display
  # Returns structured matching results for frontend consumption
  class TherapistMatchResultsWrapperType < Types::BaseObject
    description "Therapist matching results wrapper"

    field :therapists, [Types::MatchedTherapistType], null: false,
          description: "List of matched therapists (2-3 typically)"

    field :total_count, Integer, null: false,
          description: "Total number of therapists matched"

    field :matching_criteria, String, null: true,
          description: "General explanation of matching criteria used"

    # Resolve therapists with best match flag
    def therapists
      matches = object[:matches] || []
      matches.each_with_index.map do |match, index|
        {
          therapist: match.therapist,
          score: match.score,
          component_scores: match.component_scores,
          reasoning: match.reasoning,
          next_availability: match.next_availability,
          is_best_match: index == 0 # First match is best match
        }
      end
    end

    # Resolve total count
    def total_count
      (object[:matches] || []).length
    end

    # Resolve matching criteria description
    def matching_criteria
      object[:criteria_description] || default_criteria_description
    end

    private

    # Default criteria description when none provided
    def default_criteria_description
      "Therapists are matched based on their specializations, " \
      "experience with children of similar age, " \
      "availability for appointments, " \
      "and acceptance of your insurance."
    end
  end
end
