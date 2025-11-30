# frozen_string_literal: true

# SupportRequest model for tracking Intercom support requests
# Story 7.3: Support Request Tracking
#
# Tracks support requests from Intercom and links them to onboarding sessions
# to analyze support needs and improve the flow.
#
# Fields:
# - onboarding_session_id: UUID foreign key to OnboardingSession
# - intercom_conversation_id: Intercom conversation ID
# - source: Widget location (e.g., 'welcome-screen', 'insurance-verification')
# - resolved: Boolean flag indicating if support request was resolved
#
# Associations:
# - belongs_to :onboarding_session
#
# Validations:
# - Presence of onboarding_session_id, source
#
class SupportRequest < ApplicationRecord
  # Associations
  belongs_to :onboarding_session

  # Validations
  validates :source, presence: true
  validates :onboarding_session_id, presence: true

  # Scopes
  scope :resolved, -> { where(resolved: true) }
  scope :unresolved, -> { where(resolved: false) }
  scope :by_source, ->(source) { where(source: source) }
  scope :recent, -> { order(created_at: :desc) }

  # Standard source values
  STANDARD_SOURCES = %w[
    welcome-screen
    ai-intake
    insurance-verification
    session-recovery
    assessment
    error-state
  ].freeze

  # Check if source is a standard value
  #
  # @return [Boolean] true if source is in STANDARD_SOURCES
  def standard_source?
    STANDARD_SOURCES.include?(source)
  end

  # Mark this support request as resolved
  #
  # @return [Boolean] true if save successful
  def mark_resolved!
    update!(resolved: true)
  end

  # Mark this support request as unresolved
  #
  # @return [Boolean] true if save successful
  def mark_unresolved!
    update!(resolved: false)
  end
end
