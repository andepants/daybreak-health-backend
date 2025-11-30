# frozen_string_literal: true

module Types
  # GraphQL type for an available time slot
  #
  # Represents a single bookable time slot for the scheduling calendar
  class AvailableSlotType < Types::BaseObject
    description "An available appointment time slot"

    field :id, ID, null: false,
          description: "Unique identifier for the slot (formatted as therapist_id-datetime)"

    field :start_time, GraphQL::Types::ISO8601DateTime, null: false,
          description: "Start time of the slot"

    field :end_time, GraphQL::Types::ISO8601DateTime, null: false,
          description: "End time of the slot"

    field :is_available, Boolean, null: false,
          description: "Whether the slot is currently available for booking"

    field :timezone, String, null: false,
          description: "Timezone of the slot times"
  end
end
