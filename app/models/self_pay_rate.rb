# frozen_string_literal: true

# SelfPayRate model for storing transparent self-pay pricing
#
# Stores self-pay rates per session type with effective date ranges
# to support rate versioning over time. Includes sliding scale and
# package pricing options in metadata.
#
# Session Types (matching SessionRate):
# - intake: Initial assessment session
# - individual_therapy: 1:1 child-therapist session
# - family_therapy: Parent + child with therapist
#
# Example usage:
#   SelfPayRate.get_rate_for('individual_therapy')
#   # => #<SelfPayRate base_rate: 75.00>
#
# Metadata Structure:
# {
#   sliding_scale_tiers: [
#     { income_range: "0-25000", discount_percent: 50 },
#     { income_range: "25001-50000", discount_percent: 30 }
#   ],
#   package_options: [
#     { sessions: 4, total_price: 280, savings: 20, description: "4-session bundle" }
#   ]
# }
#
class SelfPayRate < ApplicationRecord
  include Auditable

  # Session type enumeration (matching SessionRate)
  enum :session_type, {
    intake: "intake",
    individual_therapy: "individual_therapy",
    family_therapy: "family_therapy"
  }, prefix: true

  # Validations
  validates :session_type, presence: true
  validates :base_rate, presence: true, numericality: { greater_than: 0 }
  validates :effective_date, presence: true
  validates :sliding_scale_available, inclusion: { in: [ true, false ] }
  validates :package_pricing_available, inclusion: { in: [ true, false ] }

  # Date range validation: end_date must be after effective_date
  validate :end_date_after_effective_date, if: -> { end_date.present? }

  # Scopes

  # Get currently active rates (effective today and not yet ended)
  scope :currently_active, -> {
    where("effective_date <= ? AND (end_date IS NULL OR end_date > ?)", Date.current, Date.current)
  }

  # Get rates effective on a specific date
  scope :effective_on, ->(date) {
    where("effective_date <= ?", date)
      .where("end_date IS NULL OR end_date > ?", date)
  }

  # Get rates for a specific session type
  scope :for_session_type, ->(session_type) {
    where(session_type: session_type)
  }

  # Class Methods

  # Find the active rate for a given session type and date
  #
  # @param session_type [String, Symbol] The session type to find rate for
  # @param date [Date] The date to find rate for (default: today)
  # @return [SelfPayRate, nil] The active rate or nil if not found
  #
  # @example
  #   SelfPayRate.get_rate_for('individual_therapy')
  #   SelfPayRate.get_rate_for('family_therapy', 1.month.ago)
  def self.get_rate_for(session_type, date = Date.current)
    for_session_type(session_type)
      .effective_on(date)
      .order(effective_date: :desc)
      .first
  end

  # Instance Methods

  # Get sliding scale tiers from metadata
  #
  # @return [Array<Hash>] Array of sliding scale tier definitions
  def sliding_scale_tiers
    return [] unless sliding_scale_available
    metadata.fetch("sliding_scale_tiers", [])
  end

  # Get package options from metadata
  #
  # @return [Array<Hash>] Array of package pricing options
  def package_options
    return [] unless package_pricing_available
    metadata.fetch("package_options", [])
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
