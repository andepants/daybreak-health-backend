# frozen_string_literal: true

module Types
  # GraphQL type for patient availability time blocks
  # Used to return availability data in queries
  #
  # @see PatientAvailability model
  class PatientAvailabilityType < Types::BaseObject
    description "A patient's availability time block for scheduling"

    field :id, ID, null: false, description: "Unique identifier"
    field :onboarding_session_id, ID, null: false, description: "ID of the onboarding session"
    field :day_of_week, Integer, null: false, description: "Day of week (0=Sunday, 6=Saturday)"
    field :day_name, String, null: false, description: "Human-readable day name (e.g., 'Monday')"
    field :start_time, String, null: false, description: "Start time (HH:MM format)"
    field :duration_minutes, Integer, null: false, description: "Duration in minutes"
    field :timezone, String, null: false, description: "IANA timezone (e.g., America/Los_Angeles)"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When this was created"

    # Format start_time as HH:MM string
    def start_time
      object.start_time.strftime("%H:%M")
    end
  end
end
