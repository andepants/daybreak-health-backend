# frozen_string_literal: true

module Mutations
  module Scheduling
    # Mutation to reschedule an appointment
    #
    # Reschedules an existing appointment to a new time using atomic transaction.
    # Cancels old appointment and creates new one in a single database transaction.
    #
    # AC 5.5.9: Parent can reschedule appointment within policy constraints
    class RescheduleAppointment < BaseMutation
      description 'Reschedule an appointment to a new time'

      # Arguments
      argument :appointment_id, ID, required: true, description: 'Appointment ID to reschedule'
      argument :new_scheduled_at, GraphQL::Types::ISO8601DateTime, required: true, description: 'New appointment date and time'

      # Return fields
      field :appointment, Types::AppointmentType, null: true, description: 'New appointment'
      field :errors, [String], null: false, description: 'Errors encountered during rescheduling'
      field :success, Boolean, null: false, description: 'Whether rescheduling was successful'

      def resolve(appointment_id:, new_scheduled_at:)
        # TODO: Add authorization check
        # Verify context[:current_user] owns the session associated with this appointment
        # For MVP: Allow any reschedule request

        # Call rescheduling service
        result = ::Scheduling::BookingService.reschedule_appointment(
          appointment_id: appointment_id,
          new_scheduled_at: new_scheduled_at
        )

        if result.success?
          # Trigger real-time subscription updates for both old and new slots
          # old_appointment = Appointment.find(appointment_id)
          # GraphqlSchema.subscriptions.trigger(
          #   'slotUpdated',
          #   { therapist_id: old_appointment.therapist_id },
          #   { slot_available: true, scheduled_at: old_appointment.scheduled_at }
          # )
          # GraphqlSchema.subscriptions.trigger(
          #   'slotUpdated',
          #   { therapist_id: result.appointment.therapist_id },
          #   { slot_available: false, scheduled_at: result.appointment.scheduled_at }
          # )

          # Log successful rescheduling
          Rails.logger.info("Appointment rescheduled: #{appointment_id} to #{new_scheduled_at}")

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
        Rails.logger.error("RescheduleAppointment mutation failed: #{e.message}")
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
