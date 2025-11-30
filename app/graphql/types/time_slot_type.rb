# frozen_string_literal: true

module Types
  class TimeSlotType < Types::BaseObject
    description 'A calculated available time slot (not backed by a database model)'

    field :start_time, GraphQL::Types::ISO8601DateTime, null: false, description: 'Start time of the available slot'
    field :end_time, GraphQL::Types::ISO8601DateTime, null: false, description: 'End time of the available slot'
    field :therapist_id, ID, null: false, description: 'ID of the therapist for this slot'
    field :duration_minutes, Integer, null: false, description: 'Duration of the slot in minutes (appointment + buffer)'
  end
end
