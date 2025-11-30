# frozen_string_literal: true

module Types
  # GraphQL type for therapist match result
  # Combines therapist profile with match scoring and availability
  #
  # Story 5.4: Matching Recommendations API
  # AC2, AC3, AC4, AC5: Therapist profile, match score, reasoning, and available slots
  class TherapistMatchResultType < Types::BaseObject
    description "A therapist match result with score, reasoning, and availability"

    field :therapist, Types::TherapistType, null: false,
          description: "Matched therapist profile"

    field :score, Integer, null: false,
          description: "Overall match score (0-100)"

    field :score_breakdown, Types::MatchScoreBreakdownType, null: false,
          description: "Breakdown of individual scoring components"

    field :reasoning, String, null: false,
          description: "Parent-friendly explanation of why this therapist matches"

    field :available_slots, [Types::TimeSlotType], null: false,
          description: "Next 3-5 available appointment slots (lazy-loaded)"

    # AC2: Therapist profile
    def therapist
      object.therapist
    end

    # AC3: Match score (0-100)
    def score
      object.score.round
    end

    # AC3: Score breakdown for transparency
    def score_breakdown
      object.component_scores
    end

    # AC3: Match reasoning
    def reasoning
      object.reasoning
    end

    # AC4, AC12: Available slots (lazy-loaded)
    # Only call AvailabilityService when this field is requested
    def available_slots
      return [] unless object.therapist

      # Get next 14 days of slots
      start_date = Date.today
      end_date = 14.days.from_now.to_date

      slots = Scheduling::AvailabilityService.available_slots(
        therapist_id: object.therapist.id,
        start_date: start_date,
        end_date: end_date
      )

      # Return first 5 slots
      slots.first(5).map { |slot| OpenStruct.new(slot) }
    rescue StandardError => e
      Rails.logger.error("Failed to load available slots: #{e.message}")
      []
    end
  end
end
