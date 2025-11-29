# frozen_string_literal: true

class Message < ApplicationRecord
  include Encryptable

  # Enums
  enum :role, {
    user: 0,
    assistant: 1,
    system: 2
  }

  # Associations
  belongs_to :onboarding_session

  # PHI Encryption
  encrypts_phi :content

  # Validations
  validates :role, presence: true
  validates :content, presence: true
  validates :onboarding_session, presence: true
end
