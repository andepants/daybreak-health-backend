# frozen_string_literal: true

module Types
  class OnboardingSessionType < Types::BaseObject
    description 'An onboarding session for parent intake'

    field :id, ID, null: false, description: 'Unique session identifier (CUID format with sess_ prefix)'
    field :status, String, null: false, description: 'Current session status'
    field :progress, GraphQL::Types::JSON, null: false, description: 'Session progress data'
    field :referral_source, String, null: true, description: 'How the parent found Daybreak'
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When session was created'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When session was last updated'
    field :expires_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When session will expire'

    # Override ID field to add 'sess_' prefix to UUID
    def id
      "sess_#{object.id.gsub('-', '')}"
    end
  end
end
