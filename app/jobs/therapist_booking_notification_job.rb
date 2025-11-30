# frozen_string_literal: true

# Sidekiq job to notify therapist of new appointment booking
#
# AC 5.5.6: Therapist is notified of new booking (internal notification system)
#
# Enqueued asynchronously after successful appointment booking.
# Does not block the booking mutation response.
class TherapistBookingNotificationJob
  include Sidekiq::Job

  sidekiq_options queue: :notifications, retry: 3

  # Perform notification job
  #
  # @param appointment_id [String] UUID of the appointment
  def perform(appointment_id)
    appointment = Appointment.find_by(id: appointment_id)

    unless appointment
      Rails.logger.warn("TherapistBookingNotificationJob: Appointment not found: #{appointment_id}")
      return
    end

    therapist = appointment.therapist
    session = appointment.onboarding_session
    child = session.child
    parent = session.parent

    Rails.logger.info("Sending booking notification to therapist: #{therapist.email}")

    # In production, this would send an actual email via ActionMailer
    # For now, we'll log the notification details
    notification_details = {
      therapist_email: therapist.email,
      therapist_name: therapist.full_name,
      appointment_time: appointment.scheduled_at,
      duration: appointment.duration_minutes,
      child_name: child&.first_name,
      child_age: calculate_age(child),
      parent_name: parent&.first_name,
      parent_contact: parent&.email || parent&.phone,
      confirmation_number: appointment.confirmation_number,
      virtual_link: appointment.virtual_link
    }

    # TODO: Replace with actual email sending
    # TherapistMailer.appointment_booked(notification_details).deliver_now
    Rails.logger.info("Therapist notification details: #{notification_details.to_json}")

    # Create audit log entry
    AuditLog.create!(
      onboarding_session_id: session.id,
      action: 'THERAPIST_NOTIFIED',
      resource: 'Appointment',
      resource_id: appointment.id,
      details: {
        therapist_id: therapist.id,
        notification_sent_at: Time.current.iso8601
      }
    )
  rescue StandardError => e
    Rails.logger.error("TherapistBookingNotificationJob failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise # Re-raise to trigger Sidekiq retry
  end

  private

  # Calculate age from date of birth
  #
  # @param child [Child] Child record
  # @return [Integer, nil] Age in years or nil
  def calculate_age(child)
    return nil unless child&.date_of_birth

    dob = child.date_of_birth.is_a?(String) ? Date.parse(child.date_of_birth) : child.date_of_birth
    ((Time.current.to_date - dob) / 365.25).floor
  rescue StandardError
    nil
  end
end
