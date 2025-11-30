# frozen_string_literal: true

module Mutations
  module Therapists
    class DeleteTherapist < BaseMutation
      description 'Soft delete a therapist by setting active=false (admin only)'

      argument :id, ID, required: true, description: 'Therapist ID to delete'

      field :success, Boolean, null: false, description: 'Whether deletion was successful'
      field :errors, [String], null: false, description: 'Errors if any'

      def resolve(id:)
        therapist = Therapist.find(id)

        # AC 5.1.9: Admin-only mutations
        authorize(therapist, :destroy?)

        # Soft delete by setting active=false
        if therapist.update(active: false)
          {
            success: true,
            errors: []
          }
        else
          {
            success: false,
            errors: therapist.errors.full_messages
          }
        end
      rescue ActiveRecord::RecordNotFound
        {
          success: false,
          errors: ['Therapist not found']
        }
      rescue Pundit::NotAuthorizedError
        {
          success: false,
          errors: ['Unauthorized: Admin access required']
        }
      rescue StandardError => e
        Rails.logger.error("DeleteTherapist failed: #{e.message}")
        {
          success: false,
          errors: [e.message]
        }
      end
    end
  end
end
