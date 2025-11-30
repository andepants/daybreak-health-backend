# frozen_string_literal: true

module Types
  # GraphQL type for a date with availability slots
  #
  # Groups time slots by date for calendar display
  class AvailableDateType < Types::BaseObject
    description "A date with its available time slots"

    field :date, GraphQL::Types::ISO8601Date, null: false,
          description: "The date (YYYY-MM-DD)"

    field :has_availability, Boolean, null: false,
          description: "Whether there are any available slots on this date"

    field :slots, [Types::AvailableSlotType], null: false,
          description: "List of available time slots for this date"
  end
end
