# frozen_string_literal: true

module Types
  class SessionRecoveryPayloadType < Types::BaseObject
    description 'Response from session recovery'

    field :session, Types::OnboardingSessionType, null: false,
      description: 'Recovered session with full progress'
    field :token, String, null: false,
      description: 'New JWT authentication token for this session'
    field :refresh_token, String, null: false,
      description: 'New refresh token for token renewal'
  end
end
