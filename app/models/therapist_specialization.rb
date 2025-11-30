# frozen_string_literal: true

class TherapistSpecialization < ApplicationRecord
  # Associations
  belongs_to :therapist

  # Validations
  validates :specialization, presence: true
  validates :specialization, uniqueness: { scope: :therapist_id }
end
