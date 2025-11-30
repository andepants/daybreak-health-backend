# frozen_string_literal: true

module Mutations
  module Scheduling
    class DeleteAvailability < BaseMutation
      description 'Delete an availability slot (admin only)'

      # Input fields
      argument :id, ID, required: true, description: 'ID of the availability slot to delete'

      # Return fields
      field :success, Boolean, null: false, description: 'Whether the deletion was successful'
      field :errors, [String], null: false, description: 'List of errors, if any'

      def resolve(id:)
        availability = TherapistAvailability.find(id)

        # Authorization check (requires admin role)
        authorize(availability, :destroy?)

        if availability.destroy
          { success: true, errors: [] }
        else
          { success: false, errors: availability.errors.full_messages }
        end
      rescue Pundit::NotAuthorizedError
        { success: false, errors: ['Unauthorized: Admin access required'] }
      rescue ActiveRecord::RecordNotFound => e
        { success: false, errors: ["Availability not found: #{e.message}"] }
      end
    end
  end
end
