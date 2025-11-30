# frozen_string_literal: true

module Mutations
  module Therapists
    class UpdateTherapist < BaseMutation
      description 'Update an existing therapist profile (admin only)'

      argument :id, ID, required: true, description: 'Therapist ID'
      argument :input, Types::Inputs::TherapistInput, required: true,
               description: 'Updated therapist profile data'

      field :therapist, Types::TherapistType, null: true, description: 'Updated therapist'
      field :success, Boolean, null: false, description: 'Whether update was successful'
      field :errors, [String], null: false, description: 'Validation errors if any'

      def resolve(id:, input:)
        therapist = Therapist.find(id)

        # AC 5.1.9: Admin-only mutations
        authorize(therapist, :update?)

        update_params = {
          first_name: input[:first_name],
          last_name: input[:last_name],
          email: input[:email],
          phone: input[:phone],
          license_type: input[:license_type],
          license_number: input[:license_number],
          license_state: input[:license_state],
          license_expiration: input[:license_expiration],
          npi_number: input[:npi_number],
          bio: input[:bio],
          photo_url: input[:photo_url],
          active: input[:active],
          languages: input[:languages],
          age_ranges: input[:age_ranges],
          treatment_modalities: input[:treatment_modalities]
        }.compact

        if therapist.update(update_params)
          # Update specializations if provided
          if input[:specializations].present?
            therapist.therapist_specializations.destroy_all
            input[:specializations].each do |spec|
              therapist.therapist_specializations.create!(specialization: spec)
            end
          end

          {
            success: true,
            therapist: therapist,
            errors: []
          }
        else
          {
            success: false,
            therapist: nil,
            errors: therapist.errors.full_messages
          }
        end
      rescue ActiveRecord::RecordNotFound
        {
          success: false,
          therapist: nil,
          errors: ['Therapist not found']
        }
      rescue Pundit::NotAuthorizedError
        {
          success: false,
          therapist: nil,
          errors: ['Unauthorized: Admin access required']
        }
      rescue StandardError => e
        Rails.logger.error("UpdateTherapist failed: #{e.message}")
        {
          success: false,
          therapist: nil,
          errors: [e.message]
        }
      end
    end
  end
end
