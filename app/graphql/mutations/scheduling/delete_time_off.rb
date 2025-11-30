# frozen_string_literal: true

module Mutations
  module Scheduling
    class DeleteTimeOff < BaseMutation
      description 'Delete a time-off period (admin only)'

      # Input fields
      argument :id, ID, required: true, description: 'ID of the time-off period to delete'

      # Return fields
      field :success, Boolean, null: false, description: 'Whether the deletion was successful'
      field :errors, [String], null: false, description: 'List of errors, if any'

      def resolve(id:)
        time_off = TherapistTimeOff.find(id)

        # Authorization check (requires admin role)
        authorize(time_off, :destroy?)

        if time_off.destroy
          { success: true, errors: [] }
        else
          { success: false, errors: time_off.errors.full_messages }
        end
      rescue Pundit::NotAuthorizedError
        { success: false, errors: ['Unauthorized: Admin access required'] }
      rescue ActiveRecord::RecordNotFound => e
        { success: false, errors: ["Time-off not found: #{e.message}"] }
      end
    end
  end
end
