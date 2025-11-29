# frozen_string_literal: true

class OnboardingSession < ApplicationRecord
  include Auditable
  include SessionStateMachine

  # Enums
  enum :status, {
    started: 0,
    in_progress: 1,
    insurance_pending: 2,
    assessment_complete: 3,
    submitted: 4,
    abandoned: 5,
    expired: 6
  }

  # AC 2.6.3: Role-based access control
  # Roles: anonymous (default), parent, coordinator, admin, system
  enum :role, {
    anonymous: 0,
    parent: 1,
    coordinator: 2,
    admin: 3,
    system: 4
  }

  # Associations
  has_one :parent, dependent: :destroy
  has_one :child, dependent: :destroy
  has_one :insurance, dependent: :destroy
  has_one :assessment, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :audit_logs, dependent: :nullify
  has_many :refresh_tokens, dependent: :destroy

  # Validations
  validates :status, presence: true
  validates :expires_at, presence: true

  # Scopes
  scope :active, -> { where.not(status: [:submitted, :abandoned, :expired]) }
  scope :expiring_soon, -> { active.where(expires_at: ..1.hour.from_now) }
  scope :expired_pending, -> { active.where('expires_at < ?', Time.current) }

  # Check if session has passed its expiration time
  # AC 2.4.4: No new activity allowed on expired sessions
  #
  # Note: This checks timestamp expiration, not status.
  # Use status.expired? to check if session is marked as expired.
  #
  # @return [Boolean] true if session has passed expiration time
  def past_expiration?
    expires_at < Time.current
  end

  # Extend session expiration by specified duration from current time (default 1 hour)
  # AC 2.2.4: Session expiresAt extended by 1 hour on activity
  # Always sets expiration to 1 hour from now on each activity
  def extend_expiration(duration = 1.hour)
    self.expires_at = Time.current + duration
  end

  # Abandon this session explicitly
  # AC 2.5.3: Mutation sets session status to ABANDONED
  # AC 2.5.4: Session data is retained per data retention policy (same as expiration)
  # AC 2.5.8: Audit log entry created with previousStatus in details
  #
  # Data Retention: Abandoned sessions follow the same 90-day retention policy
  # as expired sessions. No data is deleted on abandonment.
  #
  # Idempotency: Abandoning an already abandoned session returns success (not error)
  # per tech spec. This allows clients to retry safely.
  #
  # @param context [Hash] Optional context with IP address and user agent for audit log
  # @return [self] The abandoned session
  # @raise [ActiveRecord::RecordInvalid] If state transition is invalid
  def abandon!(context: {})
    previous_status = status

    # AC 2.5.3: Idempotent - abandoning already abandoned session is a no-op
    if abandoned?
      Rails.logger.info("Session #{id} already abandoned, skipping")
      return self
    end

    # Transition to abandoned status
    # The SessionStateMachine concern will validate this transition
    self.status = :abandoned

    # AC 2.5.4: No data deletion - session and all associated data retained
    # Transaction ensures audit log is created atomically with status change
    transaction do
      save!

      # AC 2.5.8: Create audit log with previous status in details
      create_abandonment_audit_log(previous_status, context)

      # AC 2.5.10: Optional trigger for FR32 abandoned session reminder workflow
      trigger_abandonment_notification if abandonment_notifications_enabled?
    end

    self
  end

  private

  # Create audit log entry for session abandonment
  # AC 2.5.8: action: SESSION_ABANDONED, details: { previousStatus }
  def create_abandonment_audit_log(previous_status, context)
    AuditLog.create!(
      onboarding_session_id: id,
      action: 'SESSION_ABANDONED',
      resource: 'OnboardingSession',
      resource_id: id,
      details: {
        previousStatus: previous_status,
        timestamp: Time.current.iso8601
      },
      ip_address: context[:ip_address],
      user_agent: context[:user_agent]
    )
  end

  # Check if abandonment notifications are enabled
  # AC 2.5.10: Feature flag for FR32 reminder workflow integration
  def abandonment_notifications_enabled?
    # Feature flag approach - gracefully handle if config not present
    Rails.application.config.respond_to?(:abandonment_notifications_enabled) &&
      Rails.application.config.abandonment_notifications_enabled
  rescue StandardError => e
    Rails.logger.warn("Error checking abandonment notification config: #{e.message}")
    false
  end

  # Trigger notification hook for abandoned session
  # AC 2.5.10: Integration point for future notification system (FR32)
  # Gracefully handles if notification system is unavailable
  def trigger_abandonment_notification
    # Placeholder for future notification system integration
    # This will be implemented when Epic 6 (Notifications) is built
    Rails.logger.info("Abandonment notification triggered for session #{id}")

    # Future implementation will call notification service:
    # NotificationService.send_abandonment_reminder(session: self)
  rescue StandardError => e
    # AC 2.5.10: Ensure graceful handling if notification system unavailable
    Rails.logger.error("Failed to trigger abandonment notification: #{e.message}")
    # Don't raise - notification failure should not prevent abandonment
  end
end
