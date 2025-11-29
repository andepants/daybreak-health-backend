# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Auth::RefreshToken, type: :request do
  let(:session) { create(:onboarding_session) }
  let(:device_fingerprint) { Digest::SHA256.hexdigest('test-device') }

  let(:query) do
    <<~GQL
      mutation RefreshToken($refreshToken: String!, $deviceFingerprint: String) {
        refreshToken(refreshToken: $refreshToken, deviceFingerprint: $deviceFingerprint) {
          success
          error
          token
          refreshToken
          tokenType
          expiresIn
        }
      }
    GQL
  end

  def execute_query(variables = {})
    DaybreakHealthBackendSchema.execute(
      query,
      variables: variables,
      context: {
        ip_address: '127.0.0.1',
        user_agent: 'Test User Agent'
      }
    )
  end

  describe 'with valid refresh token' do
    let!(:refresh_token) do
      ::Auth::TokenService.generate_refresh_token(
        session,
        device_fingerprint: device_fingerprint,
        ip_address: '127.0.0.1',
        user_agent: 'Test User Agent'
      )
    end

    it 'returns new access and refresh tokens' do
      result = execute_query(refreshToken: refresh_token, deviceFingerprint: device_fingerprint)
      data = result['data']['refreshToken']

      expect(data['success']).to be true
      expect(data['error']).to be_nil
      expect(data['token']).to be_present
      expect(data['refreshToken']).to be_present
      expect(data['tokenType']).to eq('Bearer')
      expect(data['expiresIn']).to eq(1.hour.to_i)
    end

    it 'returns a valid JWT access token' do
      result = execute_query(refreshToken: refresh_token, deviceFingerprint: device_fingerprint)
      data = result['data']['refreshToken']

      decoded = ::Auth::JwtService.decode(data['token'])
      expect(decoded['session_id']).to eq(session.id)
      expect(decoded['role']).to eq('anonymous')
    end

    it 'invalidates the old refresh token (token rotation)' do
      result = execute_query(refreshToken: refresh_token, deviceFingerprint: device_fingerprint)
      expect(result['data']['refreshToken']['success']).to be true

      # Second attempt with same token should fail
      result2 = execute_query(refreshToken: refresh_token, deviceFingerprint: device_fingerprint)
      expect(result2['data']['refreshToken']['success']).to be false
      expect(result2['data']['refreshToken']['error']).to include('Invalid or expired')
    end

    it 'creates an audit log entry' do
      expect {
        execute_query(refreshToken: refresh_token, deviceFingerprint: device_fingerprint)
      }.to change(AuditLog, :count).by_at_least(1)

      audit = AuditLog.where(action: 'TOKEN_REFRESHED').last
      expect(audit).to be_present
      expect(audit.resource).to eq('RefreshToken')
    end
  end

  describe 'with invalid refresh token' do
    it 'returns failure for empty token' do
      result = execute_query(refreshToken: '')
      data = result['data']['refreshToken']

      expect(data['success']).to be false
      expect(data['error']).to eq('Invalid or expired refresh token')
      expect(data['token']).to be_nil
      expect(data['refreshToken']).to be_nil
    end

    it 'returns failure for non-existent token' do
      result = execute_query(refreshToken: 'invalid-token-value')
      data = result['data']['refreshToken']

      expect(data['success']).to be false
      expect(data['error']).to eq('Invalid or expired refresh token')
    end

    it 'creates audit log for failed attempt' do
      expect {
        execute_query(refreshToken: 'invalid-token')
      }.to change(AuditLog, :count).by(1)

      audit = AuditLog.last
      expect(audit.action).to eq('TOKEN_REFRESH_FAILED')
    end
  end

  describe 'with expired refresh token' do
    let!(:expired_refresh_token) do
      token = ::Auth::TokenService.generate_refresh_token(
        session,
        device_fingerprint: device_fingerprint,
        ip_address: '127.0.0.1',
        user_agent: 'Test User Agent'
      )

      # Expire the token in the database
      RefreshToken.last.update!(expires_at: 1.day.ago)
      token
    end

    it 'returns failure for expired token' do
      result = execute_query(refreshToken: expired_refresh_token, deviceFingerprint: device_fingerprint)
      data = result['data']['refreshToken']

      expect(data['success']).to be false
      expect(data['error']).to eq('Invalid or expired refresh token')
    end
  end

  describe 'with revoked refresh token' do
    let!(:revoked_refresh_token) do
      token = ::Auth::TokenService.generate_refresh_token(
        session,
        device_fingerprint: device_fingerprint,
        ip_address: '127.0.0.1',
        user_agent: 'Test User Agent'
      )

      # Revoke the token
      RefreshToken.last.revoke!
      token
    end

    it 'returns failure for revoked token' do
      result = execute_query(refreshToken: revoked_refresh_token, deviceFingerprint: device_fingerprint)
      data = result['data']['refreshToken']

      expect(data['success']).to be false
      expect(data['error']).to eq('Invalid or expired refresh token')
    end
  end
end
