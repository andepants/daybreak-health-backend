# frozen_string_literal: true

module Types
  class TherapistTimeOffType < Types::BaseObject
    description 'A time-off period for a therapist (vacation, blocked time, etc.)'

    field :id, ID, null: false, description: 'Unique identifier for the time-off period'
    field :therapist_id, ID, null: false, description: 'ID of the therapist'
    field :start_date, GraphQL::Types::ISO8601Date, null: false, description: 'Start date of time-off period'
    field :end_date, GraphQL::Types::ISO8601Date, null: false, description: 'End date of time-off period'
    field :reason, String, null: true, description: 'Optional reason for time-off (e.g., vacation, conference)'
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When this time-off was created'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When this time-off was last updated'
  end
end
