# frozen_string_literal: true

module Mutations
  module Scheduling
    class UpdateAvailability < BaseMutation
      description 'Update an existing availability slot (admin only)'

      # Input fields
      argument :id, ID, required: true, description: 'ID of the availability slot to update'
      argument :day_of_week, Integer, required: false, description: 'Day of week (0=Sunday, 1=Monday, ..., 6=Saturday)'
      argument :start_time, String, required: false, description: 'Start time (HH:MM format, e.g., 09:00)'
      argument :end_time, String, required: false, description: 'End time (HH:MM format, e.g., 17:00)'
      argument :timezone, String, required: false, description: 'IANA timezone (e.g., America/Los_Angeles)'
      argument :is_repeating, Boolean, required: false, description: 'Whether this is a recurring weekly availability'

      # Return fields
      field :availability, Types::TherapistAvailabilityType, null: true, description: 'The updated availability slot'
      field :errors, [String], null: false, description: 'List of validation errors, if any'

      def resolve(id:, **attributes)
        availability = TherapistAvailability.find(id)

        # Authorization check (requires admin role)
        authorize(availability, :update?)

        # Parse time strings if provided
        attributes[:start_time] = Time.parse(attributes[:start_time]) if attributes[:start_time]
        attributes[:end_time] = Time.parse(attributes[:end_time]) if attributes[:end_time]

        if availability.update(attributes.compact)
          { availability: availability, errors: [] }
        else
          { availability: nil, errors: availability.errors.full_messages }
        end
      rescue Pundit::NotAuthorizedError
        { availability: nil, errors: ['Unauthorized: Admin access required'] }
      rescue ActiveRecord::RecordNotFound => e
        { availability: nil, errors: ["Availability not found: #{e.message}"] }
      rescue ArgumentError => e
        { availability: nil, errors: ["Invalid time format: #{e.message}"] }
      end
    end
  end
end
