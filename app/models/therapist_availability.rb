# frozen_string_literal: true

class TherapistAvailability < ApplicationRecord
  # Associations
  belongs_to :therapist

  # Validations
  validates :day_of_week, presence: true, inclusion: { in: 0..6 }
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :timezone, presence: true
  validates :is_repeating, inclusion: { in: [true, false] }
  validate :valid_timezone
  validate :start_time_before_end_time
  validate :no_overlapping_slots

  # Scopes
  scope :active, -> { where(created_at: ..Time.current) }
  scope :for_day_of_week, ->(day) { where(day_of_week: day) }
  scope :repeating, -> { where(is_repeating: true) }
  scope :one_time, -> { where(is_repeating: false) }

  # Class method to find overlapping availabilities
  def self.overlapping(therapist_id, day_of_week, start_time, end_time, exclude_id: nil)
    query = where(therapist_id: therapist_id, day_of_week: day_of_week)
              .where('start_time < ? AND end_time > ?', end_time, start_time)

    query = query.where.not(id: exclude_id) if exclude_id
    query
  end

  private

  def valid_timezone
    return unless timezone

    tz = ActiveSupport::TimeZone[timezone]
    if tz.nil?
      errors.add(:timezone, 'is not a valid timezone')
    end
  end

  def start_time_before_end_time
    return unless start_time && end_time

    if start_time >= end_time
      errors.add(:end_time, 'must be after start time')
    end
  end

  def no_overlapping_slots
    return unless therapist_id && day_of_week && start_time && end_time

    overlapping = TherapistAvailability.overlapping(
      therapist_id,
      day_of_week,
      start_time,
      end_time,
      exclude_id: id
    )

    if overlapping.exists?
      errors.add(:base, 'This availability slot overlaps with an existing slot for this therapist')
    end
  end
end
