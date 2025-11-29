# frozen_string_literal: true

module Types
  class AuthTokenResponseType < Types::BaseObject
    description 'Response from token refresh operations'

    field :token, String, null: false, description: 'New JWT access token'
    field :refresh_token, String, null: false, description: 'New refresh token (rotated)'
    field :token_type, String, null: false, description: 'Token type (Bearer)'
    field :expires_in, Integer, null: false, description: 'Access token expiration in seconds'
  end
end
