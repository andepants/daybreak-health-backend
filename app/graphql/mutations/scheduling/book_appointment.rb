# frozen_string_literal: true

module Mutations
  module Scheduling
    # Mutation to book an appointment with a therapist
    #
    # Books an appointment for a parent's child with a selected therapist at a specific time.
    # Uses atomic transaction with row locking to prevent double-booking race conditions.
    #
    # AC 5.5.1: Creates appointment with therapist_id, session_id, datetime, duration, status
    # AC 5.5.2: Prevents double-booking with database row locking
    # AC 5.5.4: Returns confirmation with appointment details
    # AC 5.5.5: Updates session status to APPOINTMENT_BOOKED
    # AC 5.5.6: Triggers therapist notification
    # AC 5.5.7: Triggers parent confirmation email
    # AC 5.5.8: Atomic booking using database transaction
    class BookAppointment < BaseMutation
      description 'Book an appointment with a therapist'

      # Arguments
      argument :session_id, ID, required: true, description: 'Onboarding session ID (with or without sess_ prefix)'
      argument :therapist_id, ID, required: true, description: 'Therapist ID'
      argument :scheduled_at, GraphQL::Types::ISO8601DateTime, required: true, description: 'Appointment date and time'
      argument :duration_minutes, Integer, required: false, description: 'Duration in minutes (defaults to therapist default)'

      # Return fields
      field :appointment, Types::AppointmentType, null: true, description: 'Created appointment'
      field :errors, [String], null: false, description: 'Errors encountered during booking'
      field :success, Boolean, null: false, description: 'Whether booking was successful'

      def resolve(session_id:, therapist_id:, scheduled_at:, duration_minutes: nil)
        # Extract UUID from session_id (remove sess_ prefix if present)
        session_uuid = extract_uuid(session_id)

        # Verify session existence
        session = OnboardingSession.find_by(id: session_uuid)
        unless session
          return {
            success: false,
            appointment: nil,
            errors: ['Session not found']
          }
        end

        # Authorization check - ensure session ownership
        # TODO: Implement full authentication/authorization when user context is available
        # For MVP: Basic session existence check ensures session is valid
        # Future: Verify context[:current_user]&.id == session.parent_id

        # Call booking service
        result = ::Scheduling::BookingService.book_appointment(
          session_id: session_uuid,
          therapist_id: therapist_id,
          scheduled_at: scheduled_at,
          duration_minutes: duration_minutes
        )

        if result.success?
          # Enqueue notification jobs asynchronously
          TherapistBookingNotificationJob.perform_async(result.appointment.id)
          AppointmentConfirmationJob.perform_async(result.appointment.id)

          # Trigger real-time subscription update
          # GraphqlSchema.subscriptions.trigger(
          #   'slotUpdated',
          #   { therapist_id: therapist_id },
          #   { slot_available: false, scheduled_at: scheduled_at }
          # )

          # Log successful booking
          Rails.logger.info("Appointment booked: #{result.appointment.id} for session: #{session_uuid}")

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
        Rails.logger.error("BookAppointment mutation failed: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))

        {
          success: false,
          appointment: nil,
          errors: ["An unexpected error occurred: #{e.message}"]
        }
      end

      private

      # Extract UUID from session ID (handles both with and without sess_ prefix)
      #
      # @param session_id [String] Session ID (with or without prefix)
      # @return [String] UUID
      def extract_uuid(session_id)
        if session_id.start_with?('sess_')
          # Remove 'sess_' prefix and insert hyphens to form UUID
          raw_id = session_id.sub('sess_', '')
          # UUID format: 8-4-4-4-12 characters
          "#{raw_id[0..7]}-#{raw_id[8..11]}-#{raw_id[12..15]}-#{raw_id[16..19]}-#{raw_id[20..31]}"
        else
          session_id
        end
      end
    end
  end
end
