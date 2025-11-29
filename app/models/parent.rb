# frozen_string_literal: true

class Parent < ApplicationRecord
  include Encryptable

  # Associations
  belongs_to :onboarding_session

  # PHI Encryption
  encrypts_phi :email, :phone, :first_name, :last_name

  # Validations
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true, format: { with: /\A\+?[\d\s\-\(\)]+\z/ }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :relationship, presence: true
  validates :is_guardian, inclusion: { in: [true, false] }
  validates :onboarding_session, presence: true
end
