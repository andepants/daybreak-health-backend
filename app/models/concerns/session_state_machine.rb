# frozen_string_literal: true

# Session State Machine Concern
# Manages valid status transitions for OnboardingSession
#
# Valid transitions:
# - started -> in_progress (auto on first progress update)
# - started -> abandoned (explicit)
# - started -> expired (system)
# - in_progress -> insurance_pending (manual)
# - in_progress -> abandoned (explicit)
# - in_progress -> expired (system)
# - insurance_pending -> assessment_complete (manual)
# - insurance_pending -> abandoned (explicit)
# - insurance_pending -> expired (system)
# - assessment_complete -> appointment_booked (auto after appointment creation)
# - assessment_complete -> submitted (manual)
# - assessment_complete -> abandoned (explicit)
# - assessment_complete -> expired (system)
# - appointment_booked -> submitted (manual)
# - appointment_booked -> abandoned (explicit)
# - appointment_booked -> expired (system)
# - ANY -> abandoned (exception to forward-only rule)
# - ANY -> expired (exception to forward-only rule)
# - Terminal states (abandoned, expired, submitted) -> NO transitions
module SessionStateMachine
  extend ActiveSupport::Concern

  included do
    validate :validate_status_transition, if: -> { persisted? && status_changed? }
    before_save :record_status_change_in_audit, if: -> { persisted? && status_changed? }
    after_save :invalidate_cache_on_terminal_state, if: -> { saved_change_to_status? && terminal_state? }
  end

  # Valid state transitions map
  VALID_TRANSITIONS = {
    'started' => ['in_progress', 'abandoned', 'expired'],
    'in_progress' => ['insurance_pending', 'abandoned', 'expired'],
    'insurance_pending' => ['assessment_complete', 'abandoned', 'expired'],
    'assessment_complete' => ['appointment_booked', 'submitted', 'abandoned', 'expired'],
    'appointment_booked' => ['submitted', 'abandoned', 'expired'],
    'abandoned' => [],
    'expired' => [],
    'submitted' => []
  }.freeze

  # Check if transition to new status is valid
  def can_transition_to?(new_status)
    new_status = new_status.to_s
    current = status.to_s

    # Same status is always valid
    return true if current == new_status

    # Check if transition is in valid transitions map
    valid_targets = VALID_TRANSITIONS[current] || []
    valid_targets.include?(new_status)
  end

  # Auto-transition from started to in_progress on first progress update
  def auto_transition_on_progress_update
    return unless started?

    self.status = :in_progress
  end

  # Check if session is in a terminal state
  def terminal_state?
    abandoned? || expired? || submitted?
  end

  # Check if session is active (not in terminal state)
  def active?
    !terminal_state?
  end

  private

  def validate_status_transition
    # For new records, no validation needed
    return unless persisted?

    # Get the changes to status
    changes = status_change
    return unless changes # No change

    old_status, new_status = changes
    old_status = old_status.to_s
    new_status = new_status.to_s

    # Check if the transition is valid based on old status
    valid_targets = VALID_TRANSITIONS[old_status] || []
    unless valid_targets.include?(new_status)
      errors.add(
        :status,
        "cannot transition from #{old_status} to #{new_status}"
      )
    end
  end

  def record_status_change_in_audit
    return unless persisted? && status_changed?

    # Audit log will be created automatically by Auditable concern
    # We just need to ensure the details capture the transition
    @status_transition_details = {
      old_status: status_was,
      new_status: status
    }
  end

  def invalidate_cache_on_terminal_state
    # Invalidate session progress cache when transitioning to terminal state
    # Terminal states: abandoned, expired, submitted
    cache_key = "daybreak:sessions:progress:#{id}"
    Rails.cache.delete(cache_key)
  rescue StandardError => e
    # Log error but don't fail the save operation
    Rails.logger.error("Failed to invalidate cache for session #{id}: #{e.message}")
  end
end
