# frozen_string_literal: true

module Types
  class SessionResponseType < Types::BaseObject
    description 'Response from session creation'

    field :session, Types::OnboardingSessionType, null: false, description: 'Created session'
    field :token, String, null: false, description: 'JWT authentication token'
  end
end
