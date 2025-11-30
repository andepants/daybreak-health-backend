# frozen_string_literal: true

module Mutations
  module Scheduling
    class CreateAvailability < BaseMutation
      description 'Create a recurring availability slot for a therapist (admin only)'

      # Input fields
      argument :therapist_id, ID, required: true, description: 'ID of the therapist'
      argument :day_of_week, Integer, required: true, description: 'Day of week (0=Sunday, 1=Monday, ..., 6=Saturday)'
      argument :start_time, String, required: true, description: 'Start time (HH:MM format, e.g., 09:00)'
      argument :end_time, String, required: true, description: 'End time (HH:MM format, e.g., 17:00)'
      argument :timezone, String, required: true, description: 'IANA timezone (e.g., America/Los_Angeles)'
      argument :is_repeating, Boolean, required: false, default_value: true, description: 'Whether this is a recurring weekly availability'

      # Return fields
      field :availability, Types::TherapistAvailabilityType, null: true, description: 'The created availability slot'
      field :errors, [String], null: false, description: 'List of validation errors, if any'

      def resolve(therapist_id:, day_of_week:, start_time:, end_time:, timezone:, is_repeating:)
        # Authorization check (requires admin role)
        authorize(TherapistAvailability, :create?)

        therapist = Therapist.find(therapist_id)

        # Parse time strings to Time objects
        start_time_obj = Time.parse(start_time)
        end_time_obj = Time.parse(end_time)

        availability = therapist.therapist_availabilities.build(
          day_of_week: day_of_week,
          start_time: start_time_obj,
          end_time: end_time_obj,
          timezone: timezone,
          is_repeating: is_repeating
        )

        if availability.save
          { availability: availability, errors: [] }
        else
          { availability: nil, errors: availability.errors.full_messages }
        end
      rescue Pundit::NotAuthorizedError
        { availability: nil, errors: ['Unauthorized: Admin access required'] }
      rescue ActiveRecord::RecordNotFound => e
        { availability: nil, errors: ["Therapist not found: #{e.message}"] }
      rescue ArgumentError => e
        { availability: nil, errors: ["Invalid time format: #{e.message}"] }
      end
    end
  end
end
