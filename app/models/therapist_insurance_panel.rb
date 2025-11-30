# frozen_string_literal: true

class TherapistInsurancePanel < ApplicationRecord
  # Associations
  belongs_to :therapist

  # Enums
  enum :network_status, {
    in_network: 0,
    out_of_network: 1
  }

  # Validations
  validates :insurance_name, presence: true
end
