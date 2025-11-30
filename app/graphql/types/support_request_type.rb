# frozen_string_literal: true

module Types
  # GraphQL type for SupportRequest
  # Story 7.3: Support Request Tracking
  #
  # Represents a support request from Intercom linked to an onboarding session
  #
  class SupportRequestType < Types::BaseObject
    field :id, ID, null: false, description: 'Support request ID'
    field :session_id, ID, null: false, description: 'Onboarding session ID'
    field :intercom_conversation_id, String, null: true, description: 'Intercom conversation ID'
    field :source, String, null: false, description: 'Source widget location (e.g., welcome-screen, insurance-verification)'
    field :resolved, Boolean, null: false, description: 'Whether the support request has been resolved'
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When the support request was created'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When the support request was last updated'

    # Custom resolver for session_id to return the onboarding_session_id
    def session_id
      object.onboarding_session_id
    end
  end
end
