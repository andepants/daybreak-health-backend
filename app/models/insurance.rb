# frozen_string_literal: true

class Insurance < ApplicationRecord
  include Encryptable

  # Enums
  enum :verification_status, {
    pending: 0,
    in_progress: 1,
    verified: 2,
    failed: 3,
    manual_review: 4,
    self_pay: 5
  }

  # Associations
  belongs_to :onboarding_session

  # PHI Encryption
  encrypts_phi :subscriber_name, :policy_number, :group_number, :member_id, :card_image_front, :card_image_back

  # Validations
  validates :payer_name, presence: true
  validates :subscriber_name, presence: true
  validates :member_id, presence: true
  validates :verification_status, presence: true
  validates :onboarding_session, presence: true
end
