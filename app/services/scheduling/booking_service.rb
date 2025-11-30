# frozen_string_literal: true

module Scheduling
  class BookingService
    # Result object for service responses
    class Result
      attr_reader :success, :appointment, :errors

      def initialize(success:, appointment: nil, errors: [])
        @success = success
        @appointment = appointment
        @errors = errors
      end

      def success?
        @success
      end

      def failure?
        !@success
      end
    end

    # Book an appointment with atomic transaction and row locking
    #
    # @param session_id [String] UUID of onboarding session
    # @param therapist_id [String] UUID of therapist
    # @param scheduled_at [DateTime] Appointment date/time
    # @param duration_minutes [Integer] Duration in minutes (optional, uses therapist default)
    # @return [Result] Result object with success/failure and appointment/errors
    def self.book_appointment(session_id:, therapist_id:, scheduled_at:, duration_minutes: nil)
      new.book_appointment(
        session_id: session_id,
        therapist_id: therapist_id,
        scheduled_at: scheduled_at,
        duration_minutes: duration_minutes
      )
    end

    def book_appointment(session_id:, therapist_id:, scheduled_at:, duration_minutes: nil)
      appointment = nil
      errors = []

      ActiveRecord::Base.transaction do
        # Lock therapist row to prevent race conditions
        therapist = Therapist.lock.find_by(id: therapist_id)
        unless therapist
          errors << 'Therapist not found'
          raise ActiveRecord::Rollback
        end

        unless therapist.active?
          errors << 'Therapist is not active'
          raise ActiveRecord::Rollback
        end

        # Lock session row
        session = OnboardingSession.lock.find_by(id: session_id)
        unless session
          errors << 'Session not found'
          raise ActiveRecord::Rollback
        end

        unless session.assessment_complete?
          errors << 'Session must be in assessment_complete status before booking'
          raise ActiveRecord::Rollback
        end

        # Use therapist's default duration if not provided
        duration = duration_minutes || therapist.appointment_duration_minutes

        # Validate scheduled time is in the future
        if scheduled_at <= Time.current
          errors << 'Appointment must be scheduled in the future'
          raise ActiveRecord::Rollback
        end

        # Check for slot availability (double-booking prevention)
        if slot_unavailable?(therapist, scheduled_at, duration)
          errors << 'This time slot is no longer available'
          raise ActiveRecord::Rollback
        end

        # Create the appointment
        appointment = Appointment.new(
          therapist: therapist,
          onboarding_session: session,
          scheduled_at: scheduled_at,
          duration_minutes: duration,
          status: :scheduled,
          location_type: 'virtual',
          virtual_link: generate_virtual_link(session)
        )

        unless appointment.save
          errors.concat(appointment.errors.full_messages)
          raise ActiveRecord::Rollback
        end

        # Session status update handled by Appointment after_create callback
      end

      if errors.empty? && appointment&.persisted?
        Result.new(success: true, appointment: appointment)
      else
        Result.new(success: false, errors: errors)
      end
    end

    # Cancel an appointment
    #
    # @param appointment_id [String] UUID of appointment
    # @param reason [String] Reason for cancellation
    # @return [Result] Result object with success/failure
    def self.cancel_appointment(appointment_id:, reason: nil)
      new.cancel_appointment(appointment_id: appointment_id, reason: reason)
    end

    def cancel_appointment(appointment_id:, reason: nil)
      appointment = Appointment.find_by(id: appointment_id)

      unless appointment
        return Result.new(success: false, errors: ['Appointment not found'])
      end

      unless appointment.cancellable?
        return Result.new(
          success: false,
          errors: ['Appointment cannot be cancelled (must be at least 24 hours in advance)']
        )
      end

      if appointment.cancel!(reason: reason)
        Result.new(success: true, appointment: appointment)
      else
        Result.new(success: false, errors: appointment.errors.full_messages)
      end
    end

    # Reschedule an appointment
    #
    # @param appointment_id [String] UUID of appointment
    # @param new_scheduled_at [DateTime] New appointment date/time
    # @return [Result] Result object with success/failure
    def self.reschedule_appointment(appointment_id:, new_scheduled_at:)
      new.reschedule_appointment(
        appointment_id: appointment_id,
        new_scheduled_at: new_scheduled_at
      )
    end

    def reschedule_appointment(appointment_id:, new_scheduled_at:)
      old_appointment = nil
      new_appointment = nil
      errors = []

      ActiveRecord::Base.transaction do
        # Lock and load old appointment
        old_appointment = Appointment.lock.find_by(id: appointment_id)
        unless old_appointment
          errors << 'Appointment not found'
          raise ActiveRecord::Rollback
        end

        unless old_appointment.reschedulable?
          errors << 'Appointment cannot be rescheduled (must be at least 24 hours in advance)'
          raise ActiveRecord::Rollback
        end

        # Lock therapist to check availability
        therapist = Therapist.lock.find(old_appointment.therapist_id)

        # Check if new slot is available
        if slot_unavailable?(therapist, new_scheduled_at, old_appointment.duration_minutes, exclude_appointment_id: old_appointment.id)
          errors << 'New time slot is not available'
          raise ActiveRecord::Rollback
        end

        # Cancel old appointment
        unless old_appointment.update(
          status: :cancelled,
          cancelled_at: Time.current,
          cancellation_reason: 'Rescheduled to new time'
        )
          errors.concat(old_appointment.errors.full_messages)
          raise ActiveRecord::Rollback
        end

        # Create new appointment
        new_appointment = Appointment.new(
          therapist: therapist,
          onboarding_session: old_appointment.onboarding_session,
          scheduled_at: new_scheduled_at,
          duration_minutes: old_appointment.duration_minutes,
          status: :scheduled,
          location_type: old_appointment.location_type,
          virtual_link: old_appointment.virtual_link
        )

        unless new_appointment.save
          errors.concat(new_appointment.errors.full_messages)
          raise ActiveRecord::Rollback
        end
      end

      if errors.empty? && new_appointment&.persisted?
        Result.new(success: true, appointment: new_appointment)
      else
        Result.new(success: false, errors: errors)
      end
    end

    private

    # Check if a time slot is unavailable (occupied by another appointment)
    #
    # @param therapist [Therapist] The therapist
    # @param scheduled_at [DateTime] Desired appointment time
    # @param duration_minutes [Integer] Appointment duration
    # @param exclude_appointment_id [String] Optional appointment ID to exclude from check (for rescheduling)
    # @return [Boolean] True if slot is unavailable
    def slot_unavailable?(therapist, scheduled_at, duration_minutes, exclude_appointment_id: nil)
      appointment_end = scheduled_at + duration_minutes.minutes

      query = therapist.appointments
                       .where.not(status: [:cancelled])
                       .where('scheduled_at < ? AND scheduled_at + (duration_minutes * INTERVAL \'1 minute\') > ?',
                              appointment_end,
                              scheduled_at)

      query = query.where.not(id: exclude_appointment_id) if exclude_appointment_id

      query.exists?
    end

    # Generate virtual meeting link for appointment
    #
    # @param session [OnboardingSession] The session
    # @return [String] Virtual meeting link
    def generate_virtual_link(session)
      # In production, this would integrate with a video conferencing service
      # For now, generate a placeholder link
      "https://meet.daybreakhealth.com/session-#{session.id}"
    end
  end
end
