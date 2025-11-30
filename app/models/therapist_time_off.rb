# frozen_string_literal: true

class TherapistTimeOff < ApplicationRecord
  # Associations
  belongs_to :therapist

  # Validations
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :start_date_before_or_equal_to_end_date
  validate :dates_not_in_past

  # Scopes
  scope :active, -> { where('end_date >= ?', Date.current) }
  scope :for_date_range, ->(start_date, end_date) {
    where('start_date <= ? AND end_date >= ?', end_date, start_date)
  }

  # Class method to find overlapping time-offs
  def self.overlapping(start_date, end_date)
    where('start_date <= ? AND end_date >= ?', end_date, start_date)
  end

  # Instance method to check if a date falls within this time-off period
  def covers_date?(date)
    date >= start_date && date <= end_date
  end

  private

  def start_date_before_or_equal_to_end_date
    return unless start_date && end_date

    if start_date > end_date
      errors.add(:end_date, 'must be on or after start date')
    end
  end

  def dates_not_in_past
    if start_date && start_date < Date.current
      errors.add(:start_date, 'cannot be in the past')
    end

    if end_date && end_date < Date.current
      errors.add(:end_date, 'cannot be in the past')
    end
  end
end
