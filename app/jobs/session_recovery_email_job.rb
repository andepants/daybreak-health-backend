# frozen_string_literal: true

# Background job to send session recovery email with magic link
#
# Queued when parent email is saved during intake.
# Generates a recovery token and sends email with magic link.
# Full email sending implementation in Story 6.1.
class SessionRecoveryEmailJob < ApplicationJob
  queue_as :default

  # @param session_id [String] UUID of the onboarding session
  # @param email [String] Parent's email address
  def perform(session_id, email)
    session = OnboardingSession.find_by(id: session_id)
    unless session
      Rails.logger.warn("SessionRecoveryEmailJob: Session #{session_id} not found")
      return
    end

    parent = session.parent
    unless parent
      Rails.logger.warn("SessionRecoveryEmailJob: No parent found for session #{session_id}")
      return
    end

    # Generate recovery token (15-minute TTL)
    token = Auth::RecoveryTokenService.generate(session_id)

    # Build magic link
    magic_link = build_magic_link(session_id, token)

    # Log email sending (actual sending in Story 6.1)
    Rails.logger.info("SessionRecoveryEmailJob: Would send recovery email to parent for session #{session_id}")
    Rails.logger.info("Magic link: #{magic_link}")

    # TODO: Story 6.1 - Implement actual email sending
    # EmailService.send_recovery_email(
    #   to: parent.email,
    #   first_name: parent.first_name,
    #   magic_link: magic_link
    # )

    # Create audit log
    create_audit_log(session, parent)
  rescue StandardError => e
    Rails.logger.error("SessionRecoveryEmailJob failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise # Re-raise to trigger retry
  end

  private

  def build_magic_link(session_id, token)
    # TODO: Use configured frontend URL from environment
    base_url = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    "#{base_url}/onboarding/recover?token=#{token}&session=#{session_id}"
  end

  def create_audit_log(session, parent)
    AuditLog.create!(
      onboarding_session_id: session.id,
      action: 'RECOVERY_EMAIL_SENT',
      resource: 'Parent',
      resource_id: parent.id,
      details: {
        has_email: true,
        timestamp: Time.current.iso8601
      }
    )
  end
end
