# frozen_string_literal: true

module Mutations
  module Scheduling
    # Mutation to cancel an appointment
    #
    # Cancels an existing appointment with cancellation policy enforcement (24-hour notice).
    #
    # AC 5.5.9: Parent can cancel appointment within policy constraints
    class CancelAppointment < BaseMutation
      description 'Cancel an appointment'

      # Arguments
      argument :appointment_id, ID, required: true, description: 'Appointment ID to cancel'
      argument :reason, String, required: false, description: 'Reason for cancellation'

      # Return fields
      field :appointment, Types::AppointmentType, null: true, description: 'Cancelled appointment'
      field :errors, [String], null: false, description: 'Errors encountered during cancellation'
      field :success, Boolean, null: false, description: 'Whether cancellation was successful'

      def resolve(appointment_id:, reason: nil)
        # TODO: Add authorization check
        # Verify context[:current_user] owns the session associated with this appointment
        # For MVP: Allow any cancellation request

        # Call cancellation service
        result = ::Scheduling::BookingService.cancel_appointment(
          appointment_id: appointment_id,
          reason: reason
        )

        if result.success?
          # Trigger real-time subscription update for slot availability
          # GraphqlSchema.subscriptions.trigger(
          #   'slotUpdated',
          #   { therapist_id: result.appointment.therapist_id },
          #   { slot_available: true, scheduled_at: result.appointment.scheduled_at }
          # )

          # Log successful cancellation
          Rails.logger.info("Appointment cancelled: #{appointment_id}")

          {
            success: true,
            appointment: result.appointment,
            errors: []
          }
        else
          {
            success: false,
            appointment: nil,
            errors: result.errors
          }
        end
      rescue StandardError => e
        Rails.logger.error("CancelAppointment mutation failed: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))

        {
          success: false,
          appointment: nil,
          errors: ["An unexpected error occurred: #{e.message}"]
        }
      end
    end
  end
end
