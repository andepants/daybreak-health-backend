# frozen_string_literal: true

module Types
  class TherapistAvailabilityType < Types::BaseObject
    description 'A recurring availability slot for a therapist'

    field :id, ID, null: false, description: 'Unique identifier for the availability slot'
    field :therapist_id, ID, null: false, description: 'ID of the therapist'
    field :day_of_week, Integer, null: false, description: 'Day of week (0=Sunday, 1=Monday, ..., 6=Saturday)'
    field :start_time, String, null: false, description: 'Start time of availability (HH:MM:SS format)'
    field :end_time, String, null: false, description: 'End time of availability (HH:MM:SS format)'
    field :timezone, String, null: false, description: 'IANA timezone (e.g., America/Los_Angeles)'
    field :is_repeating, Boolean, null: false, description: 'Whether this is a recurring weekly availability'
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When this availability was created'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When this availability was last updated'

    # Resolver for start_time to format as string
    def start_time
      object.start_time.strftime('%H:%M:%S')
    end

    # Resolver for end_time to format as string
    def end_time
      object.end_time.strftime('%H:%M:%S')
    end
  end
end
