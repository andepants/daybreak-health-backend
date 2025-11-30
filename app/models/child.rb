# frozen_string_literal: true

class Child < ApplicationRecord
  include Encryptable
  include Auditable

  # Associations
  belongs_to :onboarding_session

  # PHI Encryption
  # AC 3.7.3, 3.7.4, 3.7.11: Encrypt primary concerns and medical history
  encrypts_phi :first_name, :last_name, :date_of_birth, :primary_concerns, :medical_history

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :date_of_birth, presence: true
  validates :onboarding_session, presence: true

  # Custom validations for DOB
  validate :date_of_birth_not_in_future
  validate :age_within_service_range

  # Calculate age from date of birth
  # AC 3.7.8: Child's age calculated and stored
  #
  # @return [Integer, nil] Age in years, or nil if date_of_birth is blank
  def age
    return nil unless date_of_birth

    dob = parsed_dob
    return nil unless dob

    today = Date.today
    age = today.year - dob.year
    # Subtract 1 if birthday hasn't occurred yet this year
    age -= 1 if today.month < dob.month || (today.month == dob.month && today.day < dob.day)
    age
  end

  # Parse medical history from JSON text
  # AC 3.7.4: Medical history stored as structured JSON
  # Structure: { medications: [], diagnoses: [], hospitalizations: [] }
  #
  # @return [Hash, nil] Parsed medical history or nil
  def parsed_medical_history
    return nil if medical_history.blank?

    JSON.parse(medical_history)
  rescue JSON::ParserError
    nil
  end

  # Set medical history from hash
  #
  # @param data [Hash] Medical history data
  def set_medical_history(data)
    self.medical_history = data.to_json if data
  end

  private

  # Parse date of birth, memoized for efficiency
  #
  # @return [Date, nil] Parsed date or nil if invalid
  def parsed_dob
    @parsed_dob ||= begin
      Date.parse(date_of_birth) if date_of_birth.present?
    rescue ArgumentError, TypeError
      nil
    end
  end

  # AC 3.7.10: Validate DOB not in future
  def date_of_birth_not_in_future
    return unless parsed_dob

    if parsed_dob > Date.today
      errors.add(:date_of_birth, "cannot be in the future")
    end
  end

  # AC 3.7.5: Validate age within service range (5-18 years)
  # AC 3.7.10: DOB validation yields age between 5-18
  def age_within_service_range
    return unless age

    unless age.between?(5, 18)
      errors.add(:date_of_birth, "child must be between 5-18 years old for Daybreak services")
    end
  end
end
