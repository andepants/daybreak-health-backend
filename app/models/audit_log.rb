# frozen_string_literal: true

class AuditLog < ApplicationRecord
  # Associations
  belongs_to :onboarding_session, optional: true

  # Validations
  validates :action, presence: true
  validates :resource, presence: true

  # Scopes
  scope :for_session, ->(session_id) { where(onboarding_session_id: session_id) }
  scope :recent, -> { order(created_at: :desc) }
end
