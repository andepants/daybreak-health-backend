# frozen_string_literal: true

# Background job to notify care team of escalation requests
# AC 3.5.6: Care team notified of escalation request
#
# This job is queued immediately (not deferred) when a parent requests human contact.
# Integration with care team notification system (Story 6.4).
class EscalationNotificationJob < ApplicationJob
  queue_as :default

  # AC 3.5.6: Trigger care team notification when escalation requested
  # @param session_id [String] The ID of the session that requested escalation
  def perform(session_id)
    session = OnboardingSession.find(session_id)

    # Verify session actually needs human contact (defensive check)
    unless session.needs_human_contact
      Rails.logger.warn("EscalationNotificationJob called for session #{session_id} without needs_human_contact flag")
      return
    end

    # TODO: Task 5 - Integrate with actual care team notification system
    # This will be implemented when Story 6.4 notification service is available
    #
    # Expected integration:
    #   Notification::AlertService.send_escalation_notification(
    #     session: session,
    #     priority: :high,
    #     payload: {
    #       session_id: session.id,
    #       escalation_timestamp: session.escalation_requested_at,
    #       escalation_reason: session.escalation_reason,
    #       parent_contact: session.parent&.email || session.parent&.phone,
    #       progress_summary: calculate_progress_summary(session)
    #     }
    #   )

    Rails.logger.info("Escalation notification triggered for session #{session_id} " \
                      "(escalation_requested_at: #{session.escalation_requested_at})")

    # Placeholder log for notification details
    log_notification_details(session)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("EscalationNotificationJob: Session #{session_id} not found")
  rescue StandardError => e
    Rails.logger.error("EscalationNotificationJob failed for session #{session_id}: #{e.message}")
    # Re-raise to trigger Sidekiq retry mechanism
    raise
  end

  private

  # Log notification details for debugging/testing
  def log_notification_details(session)
    Rails.logger.info("Escalation Notification Details:")
    Rails.logger.info("  Session ID: #{session.id}")
    Rails.logger.info("  Escalation Time: #{session.escalation_requested_at}")
    Rails.logger.info("  Has Reason: #{session.escalation_reason.present?}")
    Rails.logger.info("  Parent Email: #{session.parent&.email || 'not provided'}")
    Rails.logger.info("  Current Status: #{session.status}")
  end
end
