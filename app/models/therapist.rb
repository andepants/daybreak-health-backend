# frozen_string_literal: true

class Therapist < ApplicationRecord
  # Associations
  has_many :therapist_specializations, dependent: :destroy
  has_many :therapist_insurance_panels, dependent: :destroy
  has_many :therapist_availabilities, dependent: :destroy
  has_many :therapist_time_offs, dependent: :destroy
  has_many :appointments, dependent: :destroy

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :license_number, uniqueness: { allow_nil: true }
  validates :npi_number, uniqueness: { allow_nil: true }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, allow_nil: true }
  validates :appointment_duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :buffer_time_minutes, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_state, ->(state) { where(license_state: state) }
  scope :with_specialization, ->(spec) {
    joins(:therapist_specializations)
      .where(therapist_specializations: { specialization: spec })
      .distinct
  }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def specializations
    therapist_specializations.pluck(:specialization)
  end

  def credentials
    "#{license_type} #{license_number}"
  end

  def total_slot_duration
    appointment_duration_minutes + buffer_time_minutes
  end

  # Check if therapist serves a specific age
  # Age ranges stored as array of strings like ["5-12", "13-17"]
  #
  # @param age [Integer] Age to check
  # @return [Boolean] True if age is in any served range
  def serves_age?(age)
    return false unless age
    return false if age_ranges.blank?

    age_ranges.any? do |range|
      min, max = parse_age_range(range)
      next false unless min && max

      age >= min && age <= max
    end
  end

  # Get minimum age served
  #
  # @return [Integer, nil] Minimum age or nil
  def age_range_min
    return nil if age_ranges.blank?

    age_ranges.map { |r| parse_age_range(r).first }.compact.min
  end

  # Get maximum age served
  #
  # @return [Integer, nil] Maximum age or nil
  def age_range_max
    return nil if age_ranges.blank?

    age_ranges.map { |r| parse_age_range(r).last }.compact.max
  end

  # Get education history from profile_data
  # Returns array of education entries with degree, institution, year
  #
  # @return [Array<Hash>] Education entries
  def education
    profile_data["education"] || []
  end

  # Get professional certifications from profile_data
  # Falls back to treatment_modalities if no certifications specified
  #
  # @return [Array<String>] Certification names
  def certifications
    profile_data["certifications"].presence || treatment_modalities.presence || []
  end

  # Get therapeutic approach description from profile_data
  # Generates a sensible default if not specified
  #
  # @return [String] Approach description
  def approach
    profile_data["approach"].presence || generate_default_approach
  end

  private

  # Generate a default therapeutic approach based on modalities
  #
  # @return [String] Default approach description
  def generate_default_approach
    modalities = treatment_modalities.presence || ["evidence-based techniques"]
    "I use an integrative approach tailored to each client's unique needs, " \
    "combining #{modalities.first(3).join(', ')} with a warm, supportive therapeutic relationship."
  end

  # Parse age range string like "5-12" into [min, max]
  #
  # @param range [String] Age range string
  # @return [Array<Integer, Integer>] Min and max ages
  def parse_age_range(range)
    return [nil, nil] unless range

    parts = range.split('-')
    return [nil, nil] unless parts.length == 2

    [parts[0].to_i, parts[1].to_i]
  end
end
