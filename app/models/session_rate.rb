# frozen_string_literal: true

# SessionRate model for configurable therapy session base rates
#
# Stores base rates per service type with effective date ranges
# to support rate versioning over time.
#
# Service Types:
# - intake: Initial assessment session
# - individual_therapy: 1:1 child-therapist session
# - family_therapy: Parent + child with therapist
# - onsite_care: School-based services
#
# Example usage:
#   SessionRate.current_rate_for(service_type: 'individual_therapy')
#   # => #<SessionRate base_rate: 150.00>
#
# Rate Versioning:
# Rates are versioned by effective_date and end_date ranges.
# When creating new rates, set end_date of previous rate to day before
# new rate's effective_date to avoid gaps or overlaps.
#
class SessionRate < ApplicationRecord
  include Auditable

  # Service type enumeration based on contracts.csv analysis
  # - intake: Initial assessment/screening session
  # - individual_therapy: 1:1 therapy session (child + therapist)
  # - family_therapy: Family session (parent + child + therapist)
  # - onsite_care: School-based mental health services
  enum :service_type, {
    intake: "intake",
    individual_therapy: "individual_therapy",
    family_therapy: "family_therapy",
    onsite_care: "onsite_care"
  }, prefix: true

  # Validations
  validates :service_type, presence: true
  validates :base_rate, presence: true, numericality: { greater_than: 0 }
  validates :effective_date, presence: true

  # Date range validation: end_date must be after effective_date
  validate :end_date_after_effective_date, if: -> { end_date.present? }

  # Scopes

  # Get current active rates (no end_date or end_date in future)
  scope :active, -> {
    where("end_date IS NULL OR end_date >= ?", Date.current)
  }

  # Get rates effective on a specific date
  scope :effective_on, ->(date) {
    where("effective_date <= ?", date)
      .where("end_date IS NULL OR end_date >= ?", date)
  }

  # Get rates for a specific service type
  scope :for_service_type, ->(service_type) {
    where(service_type: service_type)
  }

  # Class Methods

  # Find the current rate for a given service type and date
  #
  # @param service_type [String, Symbol] The service type to find rate for
  # @param date [Date] The date to find rate for (default: today)
  # @return [SessionRate, nil] The active rate or nil if not found
  #
  # @example
  #   SessionRate.current_rate_for(service_type: 'individual_therapy')
  #   SessionRate.current_rate_for(service_type: 'family_therapy', date: 1.month.ago)
  def self.current_rate_for(service_type:, date: Date.current)
    for_service_type(service_type)
      .effective_on(date)
      .order(effective_date: :desc)
      .first
  end

  # Find base rate amount for a service type
  #
  # @param service_type [String, Symbol] The service type
  # @param date [Date] The date to find rate for (default: today)
  # @return [BigDecimal, nil] The base rate amount or nil if not found
  #
  # @example
  #   SessionRate.base_rate_for(service_type: 'individual_therapy')
  #   # => #<BigDecimal:0x00007f9a8a0c3d40 '150.0'>
  def self.base_rate_for(service_type:, date: Date.current)
    rate = current_rate_for(service_type: service_type, date: date)
    rate&.base_rate
  end

  private

  # Validate that end_date is after effective_date
  def end_date_after_effective_date
    return unless end_date && effective_date

    if end_date < effective_date
      errors.add(:end_date, "must be after effective_date")
    end
  end
end
