# frozen_string_literal: true

# SessionCleanupJob expires inactive sessions
#
# This job runs every 15 minutes via Sidekiq-cron to mark sessions as expired
# when their expires_at timestamp has passed. It supports the session lifecycle
# by automatically transitioning sessions to the expired state.
#
# AC 2.4.1: Sessions with expiresAt in the past marked as EXPIRED
# AC 2.4.5: Cleanup job runs every 15 minutes via scheduled task
# AC 2.4.7: Audit log: action: SESSION_EXPIRED
#
# Example:
#   SessionCleanupJob.perform_now  # Manual execution
#   SessionCleanupJob.perform_later # Async execution
class SessionCleanupJob < ApplicationJob
  queue_as :default

  # Retry on transient errors with exponential backoff
  retry_on ActiveRecord::Deadlocked, wait: :exponentially_longer, attempts: 3
  retry_on ActiveRecord::QueryCanceled, wait: :exponentially_longer, attempts: 3

  def perform
    Rails.logger.info('SessionCleanupJob: Starting session expiration check')

    expired_count = 0

    # Find all active sessions that have expired
    # AC 2.4.1: Sessions with expiresAt in the past marked as EXPIRED
    expired_sessions = OnboardingSession
                         .where.not(status: [:expired, :abandoned, :submitted])
                         .where('expires_at < ?', Time.current)

    expired_sessions.find_each do |session|
      begin
        # Update session status to expired
        session.update!(status: :expired)

        # AC 2.4.7: Create audit log for session expiration
        create_expiration_audit_log(session)

        expired_count += 1
      rescue StandardError => e
        Rails.logger.error(
          "SessionCleanupJob: Failed to expire session #{session.id}: #{e.message}"
        )
        # Continue processing other sessions even if one fails
        next
      end
    end

    # Log summary of expiration run
    Rails.logger.info(
      "SessionCleanupJob: Completed. Expired #{expired_count} session(s)"
    )

    expired_count
  end

  private

  # Create audit log entry for session expiration
  # AC 2.4.7: Audit log: action: SESSION_EXPIRED
  def create_expiration_audit_log(session)
    AuditLog.create!(
      onboarding_session_id: session.id,
      action: 'SESSION_EXPIRED',
      resource: 'OnboardingSession',
      resource_id: session.id,
      details: {
        expired_at: Time.current,
        previous_status: session.status_before_last_save || 'unknown',
        expires_at: session.expires_at
      }
    )
  end
end
