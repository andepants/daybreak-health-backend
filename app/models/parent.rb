# frozen_string_literal: true

class Parent < ApplicationRecord
  include Encryptable

  # Associations
  belongs_to :onboarding_session

  # Enums
  enum :relationship, {
    parent: 0,
    guardian: 1,
    grandparent: 2,
    foster_parent: 3,
    other: 4
  }

  # PHI Encryption
  encrypts_phi :email, :phone, :first_name, :last_name

  # Validations
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :relationship, presence: true
  validates :is_guardian, inclusion: { in: [true, false] }
  validates :onboarding_session, presence: true
  validate :phone_must_be_valid_e164

  private

  def phone_must_be_valid_e164
    return if phone.blank?

    parsed = Phonelib.parse(phone, 'US')
    unless parsed.valid?
      errors.add(:phone, 'must be a valid phone number in E.164 format')
    end
  end
end
