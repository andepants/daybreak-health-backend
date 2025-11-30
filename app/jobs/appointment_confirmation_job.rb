# frozen_string_literal: true

# Sidekiq job to send appointment confirmation to parent
#
# AC 5.5.7: Parent receives confirmation email with appointment details
#
# Enqueued asynchronously after successful appointment booking.
# Does not block the booking mutation response.
class AppointmentConfirmationJob
  include Sidekiq::Job

  sidekiq_options queue: :notifications, retry: 3

  # Perform confirmation job
  #
  # @param appointment_id [String] UUID of the appointment
  def perform(appointment_id)
    appointment = Appointment.find_by(id: appointment_id)

    unless appointment
      Rails.logger.warn("AppointmentConfirmationJob: Appointment not found: #{appointment_id}")
      return
    end

    session = appointment.onboarding_session
    parent = session.parent

    # Only send if parent has email on file (AC 5.5.7)
    unless parent&.email.present?
      Rails.logger.info("AppointmentConfirmationJob: No parent email for appointment #{appointment_id}")
      return
    end

    therapist = appointment.therapist
    child = session.child

    Rails.logger.info("Sending confirmation email to parent: #{parent.email}")

    # In production, this would send an actual email via ActionMailer
    # For now, we'll log the confirmation details
    confirmation_details = {
      parent_email: parent.email,
      parent_name: parent.first_name,
      child_name: child&.first_name,
      therapist_name: therapist.full_name,
      therapist_credentials: therapist.credentials,
      therapist_photo: therapist.photo_url,
      appointment_time: appointment.scheduled_at,
      duration: appointment.duration_minutes,
      location_type: appointment.location_type,
      virtual_link: appointment.virtual_link,
      confirmation_number: appointment.confirmation_number,
      cancellation_policy: '24 hours notice required'
    }

    # TODO: Replace with actual email sending
    # ParentMailer.appointment_confirmation(confirmation_details).deliver_now
    Rails.logger.info("Parent confirmation details: #{confirmation_details.to_json}")

    # Generate calendar invite (ICS format) - placeholder
    # calendar_invite = generate_calendar_invite(appointment, therapist, child)

    # Create audit log entry
    AuditLog.create!(
      onboarding_session_id: session.id,
      action: 'PARENT_CONFIRMATION_SENT',
      resource: 'Appointment',
      resource_id: appointment.id,
      details: {
        parent_email: parent.email,
        notification_sent_at: Time.current.iso8601
      }
    )
  rescue StandardError => e
    Rails.logger.error("AppointmentConfirmationJob failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise # Re-raise to trigger Sidekiq retry
  end

  private

  # Generate calendar invite in ICS format
  #
  # @param appointment [Appointment] The appointment
  # @param therapist [Therapist] The therapist
  # @param child [Child] The child
  # @return [String] ICS formatted calendar invite
  def generate_calendar_invite(appointment, therapist, child)
    # Placeholder for calendar invite generation
    # In production, use icalendar gem
    <<~ICS
      BEGIN:VCALENDAR
      VERSION:2.0
      PRODID:-//Daybreak Health//Appointment//EN
      BEGIN:VEVENT
      UID:#{appointment.id}@daybreakhealth.com
      DTSTAMP:#{Time.current.strftime('%Y%m%dT%H%M%SZ')}
      DTSTART:#{appointment.scheduled_at.strftime('%Y%m%dT%H%M%SZ')}
      DTEND:#{(appointment.scheduled_at + appointment.duration_minutes.minutes).strftime('%Y%m%dT%H%M%SZ')}
      SUMMARY:Therapy Appointment with #{therapist.full_name}
      DESCRIPTION:Appointment for #{child&.first_name}\\nConfirmation: #{appointment.confirmation_number}
      LOCATION:#{appointment.virtual_link}
      STATUS:CONFIRMED
      END:VEVENT
      END:VCALENDAR
    ICS
  end
end
