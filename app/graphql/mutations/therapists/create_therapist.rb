# frozen_string_literal: true

module Mutations
  module Therapists
    class CreateTherapist < BaseMutation
      description 'Create a new therapist profile (admin only)'

      argument :input, Types::Inputs::TherapistInput, required: true,
               description: 'Therapist profile data'

      field :therapist, Types::TherapistType, null: true, description: 'Created therapist'
      field :success, Boolean, null: false, description: 'Whether creation was successful'
      field :errors, [String], null: false, description: 'Validation errors if any'

      def resolve(input:)
        # AC 5.1.9: Admin-only mutations
        authorize(Therapist, :create?)

        therapist = Therapist.new(
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
          active: input[:active].nil? ? true : input[:active],
          languages: input[:languages] || [],
          age_ranges: input[:age_ranges] || [],
          treatment_modalities: input[:treatment_modalities] || []
        )

        if therapist.save
          # Create specializations if provided
          if input[:specializations].present?
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
      rescue Pundit::NotAuthorizedError
        {
          success: false,
          therapist: nil,
          errors: ['Unauthorized: Admin access required']
        }
      rescue StandardError => e
        Rails.logger.error("CreateTherapist failed: #{e.message}")
        {
          success: false,
          therapist: nil,
          errors: [e.message]
        }
      end
    end
  end
end
