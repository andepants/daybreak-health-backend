# frozen_string_literal: true

# Patient availability time blocks for scheduling
#
# Stores when a patient/parent is available for therapy sessions.
# Used by the matching service to filter and score therapists based
# on availability overlap.
#
# Example: A patient available Monday 9am-5pm would have multiple records:
#   [{ day_of_week: 1, start_time: "09:00", duration_minutes: 60 },
#    { day_of_week: 1, start_time: "10:00", duration_minutes: 60 }, ...]
#
# @see TherapistAvailability for the corresponding therapist model
# @see Scheduling::MatchingService for how this data is used in matching
#
class PatientAvailability < ApplicationRecord
  # Associations
  belongs_to :onboarding_session

  # Validations
  validates :day_of_week, presence: true, inclusion: { in: 0..6 }
  validates :start_time, presence: true
  validates :duration_minutes,
            presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 480 }
  validates :timezone, presence: true
  validate :valid_timezone

  # Scopes
  scope :for_day, ->(day) { where(day_of_week: day) }
  scope :for_session, ->(session_id) { where(onboarding_session_id: session_id) }
  scope :ordered, -> { order(:day_of_week, :start_time) }

  # Day name constants for display
  DAY_NAMES = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze

  # Get human-readable day name
  #
  # @return [String] Day name (e.g., "Monday")
  def day_name
    DAY_NAMES[day_of_week]
  end

  # Calculate end time of this availability block
  #
  # @return [Time] End time
  def end_time
    start_time + duration_minutes.minutes
  end

  # Check if this availability overlaps with a therapist slot
  # Used by matching service to calculate overlap scores
  #
  # @param therapist_slot [TherapistAvailability] Therapist availability slot
  # @return [Boolean] True if there is any overlap
  def overlaps_with?(therapist_slot)
    return false unless day_of_week == therapist_slot.day_of_week

    patient_end = end_time
    therapist_end = therapist_slot.end_time

    # Check for overlap: patient_start < therapist_end AND patient_end > therapist_start
    start_time < therapist_end && patient_end > therapist_slot.start_time
  end

  # Calculate overlap duration in minutes with a therapist slot
  #
  # @param therapist_slot [TherapistAvailability] Therapist availability slot
  # @return [Integer] Overlap duration in minutes (0 if no overlap)
  def overlap_minutes(therapist_slot)
    return 0 unless overlaps_with?(therapist_slot)

    overlap_start = [start_time, therapist_slot.start_time].max
    overlap_end = [end_time, therapist_slot.end_time].min

    ((overlap_end - overlap_start) / 60).to_i
  end

  # Convert to hash for JSON serialization
  #
  # @return [Hash] Availability data
  def to_availability_hash
    {
      day_of_week: day_of_week,
      day_name: day_name,
      start_time: start_time.strftime("%H:%M"),
      duration_minutes: duration_minutes,
      timezone: timezone
    }
  end

  private

  # Validate timezone is a valid IANA timezone
  def valid_timezone
    return unless timezone

    tz = ActiveSupport::TimeZone[timezone]
    errors.add(:timezone, "is not a valid timezone") if tz.nil?
  end
end
