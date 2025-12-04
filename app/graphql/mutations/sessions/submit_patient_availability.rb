# frozen_string_literal: true

module Mutations
  module Sessions
    # SubmitPatientAvailability - Submit patient availability time blocks
    #
    # Replaces any existing availability blocks with the new set of blocks.
    # This is used in the onboarding flow to collect when the patient is
    # available for therapy sessions, which is then used in therapist matching.
    #
    # Authorization: Requires valid JWT token (uses current_session from context)
    #
    # Input:
    # - availabilities: Array of availability blocks (day_of_week, start_time, duration_minutes)
    # - timezone: IANA timezone string (e.g., "America/Los_Angeles")
    #
    # Behavior:
    # - Clears existing availability blocks for the session
    # - Creates new blocks from the input
    # - Validates at least one block is provided
    # - Extends session expiration on success
    #
    # @see PatientAvailability model
    # @see Scheduling::MatchingService for how this data is used
    class SubmitPatientAvailability < BaseMutation
      description "Submit patient availability time blocks for scheduling"

      argument :availabilities, [Types::Inputs::PatientAvailabilityInput], required: true,
               description: "Array of availability time blocks"
      argument :timezone, String, required: true,
               description: "IANA timezone (e.g., America/Los_Angeles)"

      field :success, Boolean, null: false, description: "Whether the operation succeeded"
      field :patient_availabilities, [Types::PatientAvailabilityType], null: true,
            description: "The created availability blocks"
      field :errors, [String], null: false, description: "Error messages if any"

      def resolve(availabilities:, timezone:)
        # Use current_session from JWT authentication context
        session = current_session

        unless session
          return {
            success: false,
            patient_availabilities: nil,
            errors: ["Session not found - please ensure you are authenticated"]
          }
        end

        # Check session state
        if session.past_expiration?
          return {
            success: false,
            patient_availabilities: nil,
            errors: ["Session has expired"]
          }
        end

        if session.abandoned?
          return {
            success: false,
            patient_availabilities: nil,
            errors: ["Session has been abandoned"]
          }
        end

        # Validate at least one availability block
        if availabilities.blank?
          return {
            success: false,
            patient_availabilities: nil,
            errors: ["At least one availability time block is required"]
          }
        end

        # Validate timezone
        unless ActiveSupport::TimeZone[timezone]
          return {
            success: false,
            patient_availabilities: nil,
            errors: ["Invalid timezone: #{timezone}"]
          }
        end

        # Process availability blocks in a transaction
        created_availabilities = []
        errors = []

        session.transaction do
          # Clear existing availabilities
          session.patient_availabilities.destroy_all

          # Create new availabilities
          availabilities.each do |avail|
            pa = session.patient_availabilities.build(
              day_of_week: avail[:day_of_week],
              start_time: Time.parse(avail[:start_time]),
              duration_minutes: avail[:duration_minutes] || 60,
              timezone: timezone
            )

            if pa.save
              created_availabilities << pa
            else
              errors.concat(pa.errors.full_messages)
            end
          end

          # If any errors, rollback the transaction
          if errors.any?
            raise ActiveRecord::Rollback
          end

          # Extend session expiration on success
          session.extend_expiration
          session.save!
        end

        if errors.any?
          {
            success: false,
            patient_availabilities: nil,
            errors: errors
          }
        else
          {
            success: true,
            patient_availabilities: created_availabilities,
            errors: []
          }
        end
      rescue ArgumentError => e
        # Handle Time.parse errors for invalid time formats
        {
          success: false,
          patient_availabilities: nil,
          errors: ["Invalid time format: #{e.message}"]
        }
      end
    end
  end
end
