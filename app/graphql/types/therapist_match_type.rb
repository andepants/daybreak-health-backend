# frozen_string_literal: true

module Types
  # GraphQL type for TherapistMatch model
  # Represents a matching result record with analytics data
  #
  # Story 5.4: Matching Recommendations API
  class TherapistMatchType < Types::BaseObject
    description "A therapist matching record for analytics"

    field :id, ID, null: false,
          description: "Match record ID"

    field :onboarding_session_id, ID, null: false,
          description: "Session this match was performed for"

    field :matched_therapists, GraphQL::Types::JSON, null: false,
          description: "Array of matched therapist data with scores"

    field :criteria_used, GraphQL::Types::JSON, null: false,
          description: "Criteria used for matching"

    field :processing_time_ms, Integer, null: false,
          description: "Time taken to perform matching (milliseconds)"

    field :selected_therapist_id, ID, null: true,
          description: "ID of therapist selected by parent"

    field :selected_therapist, Types::TherapistType, null: true,
          description: "Selected therapist profile"

    field :created_at, GraphQL::Types::ISO8601DateTime, null: false,
          description: "When matching was performed"

    # Selected therapist
    def selected_therapist
      object.selected_therapist
    end
  end
end
