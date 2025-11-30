# frozen_string_literal: true

class Appointment < ApplicationRecord
  include Auditable

  # Enums
  enum :status, {
    scheduled: 0,
    confirmed: 1,
    cancelled: 2,
    completed: 3,
    no_show: 4
  }

  # Associations
  belongs_to :therapist
  belongs_to :onboarding_session

  # Validations
  validates :scheduled_at, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validate :scheduled_at_in_future, on: :create
  validate :no_double_booking
  validate :therapist_must_be_active
  validate :session_must_be_assessment_complete

  # Scopes
  scope :upcoming, -> { where('scheduled_at >= ?', Time.current).where.not(status: [:cancelled, :completed]) }
  scope :past, -> { where('scheduled_at < ?', Time.current) }
  scope :for_therapist, ->(therapist_id) { where(therapist_id: therapist_id) }
  scope :for_session, ->(session_id) { where(onboarding_session_id: session_id) }
  scope :active, -> { where.not(status: [:cancelled]) }
  scope :on_date, ->(date) {
    where(scheduled_at: date.beginning_of_day..date.end_of_day)
  }
  scope :between_dates, ->(start_date, end_date) {
    where(scheduled_at: start_date..end_date)
  }

  # Callbacks
  after_create :update_session_status_to_booked
  after_create :log_appointment_created
  after_update :log_appointment_status_change, if: :saved_change_to_status?

  # Instance Methods

  # Generate confirmation number from appointment ID
  # @return [String] Formatted confirmation number
  def confirmation_number
    "APT-#{id.to_s[0, 8].upcase}"
  end

  # Check if appointment can be cancelled
  # @return [Boolean] True if appointment is at least 24 hours away
  def cancellable?
    return false if cancelled? || completed?
    return false if scheduled_at < Time.current

    scheduled_at > 24.hours.from_now
  end

  # Check if appointment can be rescheduled
  # @return [Boolean] True if appointment is at least 24 hours away
  def reschedulable?
    cancellable?
  end

  # Cancel this appointment
  # @param reason [String] Reason for cancellation
  # @return [Boolean] True if successful
  def cancel!(reason: nil)
    return false unless cancellable?

    update!(
      status: :cancelled,
      cancelled_at: Time.current,
      cancellation_reason: reason
    )

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Confirm this appointment
  # @return [Boolean] True if successful
  def confirm!
    return false unless scheduled?

    update(status: :confirmed, confirmed_at: Time.current)
  end

  # Mark appointment as completed
  # @return [Boolean] True if successful
  def complete!
    return false unless past?

    update(status: :completed)
  end

  # Mark appointment as no-show
  # @return [Boolean] True if successful
  def mark_no_show!
    return false unless past?

    update(status: :no_show)
  end

  # Check if appointment is in the past
  # @return [Boolean]
  def past?
    scheduled_at < Time.current
  end

  # Check if appointment is in the future
  # @return [Boolean]
  def future?
    scheduled_at >= Time.current
  end

  private

  # Validate scheduled_at is in the future
  def scheduled_at_in_future
    return unless scheduled_at

    if scheduled_at <= Time.current
      errors.add(:scheduled_at, 'must be in the future')
    end
  end

  # Prevent double-booking at application level
  # Database unique index provides final protection
  def no_double_booking
    return unless therapist_id && scheduled_at
    return if cancelled? # Skip check if this appointment is cancelled

    # Calculate this appointment's time range
    appointment_end = scheduled_at + duration_minutes.minutes

    # Find appointments that overlap with this time range
    # Overlap occurs when: existing.start < this.end AND existing.end > this.start
    overlapping = Appointment
                  .where(therapist_id: therapist_id)
                  .where.not(status: :cancelled)
                  .where.not(id: id)
                  .where('scheduled_at < ? AND scheduled_at + (duration_minutes * INTERVAL \'1 minute\') > ?',
                         appointment_end,
                         scheduled_at)

    if overlapping.exists?
      errors.add(:base, 'This time slot conflicts with an existing appointment')
    end
  end

  # Validate therapist is active
  def therapist_must_be_active
    return unless therapist

    unless therapist.active?
      errors.add(:therapist, 'must be active')
    end
  end

  # Validate session is in assessment_complete status
  def session_must_be_assessment_complete
    return unless onboarding_session

    unless onboarding_session.assessment_complete?
      errors.add(:onboarding_session, 'must be in assessment_complete status before booking')
    end
  end

  # Update session status to appointment_booked after appointment creation
  def update_session_status_to_booked
    # Use update! to raise on validation errors
    # This is within the transaction from BookingService, so it will rollback appointment creation
    onboarding_session.update!(status: :appointment_booked)
  rescue StandardError => e
    Rails.logger.error("Failed to update session status: #{e.message}")
    # Re-raise to trigger transaction rollback in BookingService
    raise
  end

  # Log appointment creation in audit log
  def log_appointment_created
    # Auditable concern will automatically log this
    # Additional custom logging can be added here if needed
  end

  # Log appointment status changes in audit log
  def log_appointment_status_change
    # Auditable concern will automatically log this
    # Additional custom logging can be added here if needed
  end
end
