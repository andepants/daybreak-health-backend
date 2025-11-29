# frozen_string_literal: true

class Child < ApplicationRecord
  include Encryptable

  # Associations
  belongs_to :onboarding_session

  # PHI Encryption
  encrypts_phi :first_name, :last_name, :date_of_birth

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :date_of_birth, presence: true
  validates :gender, presence: true
  validates :onboarding_session, presence: true
end
