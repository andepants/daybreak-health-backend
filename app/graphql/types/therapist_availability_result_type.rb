# frozen_string_literal: true

module Types
  # GraphQL type for therapist availability query result
  #
  # Returns structured availability data grouped by date for the scheduling calendar.
  # Used by GetTherapistAvailability frontend query.
  #
  # Story 5.2: Availability Management
  class TherapistAvailabilityResultType < Types::BaseObject
    description "Therapist availability results grouped by date"

    field :therapist_id, ID, null: false,
          description: "Therapist ID"

    field :therapist_name, String, null: false,
          description: "Therapist full name"

    field :therapist_photo_url, String, null: true,
          description: "Therapist photo URL"

    field :timezone, String, null: false,
          description: "Timezone for the availability data"

    field :available_dates, [Types::AvailableDateType], null: false,
          description: "List of dates with availability information"
  end
end
