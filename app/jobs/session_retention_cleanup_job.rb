# frozen_string_literal: true

# SessionRetentionCleanupJob handles hard deletion of expired sessions
# after the retention period has passed.
#
# AC 2.4.2: Expired sessions retained in database for 90 days (compliance)
# AC 2.4.3: Associated data (messages, progress) retained with session
#
# This job runs on a scheduled basis (daily or weekly) to permanently delete
# expired sessions that have been retained for the configured retention period.
# The retention period defaults to 90 days for compliance requirements.
#
# Example:
#   SessionRetentionCleanupJob.perform_now  # Manual execution
#   SessionRetentionCleanupJob.perform_later # Async execution
class SessionRetentionCleanupJob < ApplicationJob
  queue_as :low

  # Retry on transient errors with exponential backoff
  retry_on ActiveRecord::Deadlocked, wait: :exponentially_longer, attempts: 3
  retry_on ActiveRecord::QueryCanceled, wait: :exponentially_longer, attempts: 3

  def perform
    Rails.logger.info('SessionRetentionCleanupJob: Starting retention cleanup')

    retention_days = Rails.configuration.data_retention_days
    retention_threshold = retention_days.days.ago

    deleted_count = 0

    # Find expired sessions that have exceeded the retention period
    # AC 2.4.2: Expired sessions retained for 90 days (compliance)
    old_expired_sessions = OnboardingSession
                             .where(status: :expired)
                             .where('updated_at < ?', retention_threshold)

    old_expired_sessions.find_each do |session|
      begin
        # Create final audit log before deletion
        create_deletion_audit_log(session)

        # Hard delete session and associated data
        # AC 2.4.3: Associated data (messages, progress) retained with session
        # Note: dependent: :destroy on associations handles cascading deletion
        session.destroy!

        deleted_count += 1
      rescue StandardError => e
        Rails.logger.error(
          "SessionRetentionCleanupJob: Failed to delete session #{session.id}: #{e.message}"
        )
        # Continue processing other sessions even if one fails
        next
      end
    end

    # Log summary of retention cleanup run
    Rails.logger.info(
      "SessionRetentionCleanupJob: Completed. Deleted #{deleted_count} session(s) " \
      "older than #{retention_days} days"
    )

    deleted_count
  end

  private

  # Create audit log entry before permanent deletion
  def create_deletion_audit_log(session)
    AuditLog.create!(
      onboarding_session_id: nil, # Session will be deleted, don't link
      action: 'SESSION_DELETED',
      resource: 'OnboardingSession',
      resource_id: session.id,
      details: {
        deleted_at: Time.current,
        retention_period_days: Rails.configuration.data_retention_days,
        expired_at: session.updated_at,
        created_at: session.created_at
      }
    )
  end
end
