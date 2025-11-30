# frozen_string_literal: true

module Mutations
  module Scheduling
    class CreateTimeOff < BaseMutation
      description 'Create a time-off period for a therapist (admin only)'

      # Input fields
      argument :therapist_id, ID, required: true, description: 'ID of the therapist'
      argument :start_date, GraphQL::Types::ISO8601Date, required: true, description: 'Start date of time-off'
      argument :end_date, GraphQL::Types::ISO8601Date, required: true, description: 'End date of time-off'
      argument :reason, String, required: false, description: 'Optional reason for time-off (e.g., vacation, conference)'

      # Return fields
      field :time_off, Types::TherapistTimeOffType, null: true, description: 'The created time-off period'
      field :errors, [String], null: false, description: 'List of validation errors, if any'

      def resolve(therapist_id:, start_date:, end_date:, reason: nil)
        # Authorization check (requires admin role)
        authorize(TherapistTimeOff, :create?)

        therapist = Therapist.find(therapist_id)

        time_off = therapist.therapist_time_offs.build(
          start_date: start_date,
          end_date: end_date,
          reason: reason
        )

        if time_off.save
          { time_off: time_off, errors: [] }
        else
          { time_off: nil, errors: time_off.errors.full_messages }
        end
      rescue Pundit::NotAuthorizedError
        { time_off: nil, errors: ['Unauthorized: Admin access required'] }
      rescue ActiveRecord::RecordNotFound => e
        { time_off: nil, errors: ["Therapist not found: #{e.message}"] }
      end
    end
  end
end
