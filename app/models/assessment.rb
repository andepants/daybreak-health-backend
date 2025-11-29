# frozen_string_literal: true

class Assessment < ApplicationRecord
  include Encryptable

  # Associations
  belongs_to :onboarding_session

  # PHI Encryption
  # AC 2.6.6: Assessment responses contain sensitive health information
  encrypts_phi :responses

  # Validations
  validates :responses, presence: true
  validates :consent_given, inclusion: { in: [true, false] }
  validates :onboarding_session, presence: true
  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
end
