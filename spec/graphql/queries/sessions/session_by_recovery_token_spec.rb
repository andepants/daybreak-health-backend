# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::Sessions::SessionByRecoveryToken, type: :graphql do
  let(:redis) { Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')) }
  let(:session) { create(:onboarding_session, :with_parent, :with_progress, status: :in_progress) }
  let(:parent) { session.parent }
  let(:recovery_token) do
    Auth::RecoveryTokenService.generate_recovery_token(
      session_id: session.id,
      email: parent.email
    )
  end

  let(:context) do
    {
      ip_address: '192.168.1.1',
      user_agent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)'
    }
  end

  let(:query) do
    <<~GQL
      query SessionByRecoveryToken($recoveryToken: String!) {
        sessionByRecoveryToken(recoveryToken: $recoveryToken) {
          session {
            id
            status
            progress
          }
          token
          refreshToken
        }
      }
    GQL
  end

  before do
    redis.flushdb
  end

  after do
    redis.flushdb
  end

  describe 'successful recovery' do
    it 'returns session with valid token' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { recoveryToken: recovery_token },
        context: context
      )

      data = result.dig('data', 'sessionByRecoveryToken')
      expect(data).to be_present
      # ID is returned with sess_ prefix
      expect(data['session']['id']).to eq("sess_#{session.id.gsub('-', '')}")
      expect(data['session']['status']).to eq('in_progress')
      expect(data['session']['progress']).to eq(session.progress)
    end

    it 'issues new JWT token' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { recoveryToken: recovery_token },
        context: context
      )

      token = result.dig('data', 'sessionByRecoveryToken', 'token')
      expect(token).to be_present

      # Decode and verify token
      decoded = Auth::JwtService.decode(token)
      expect(decoded).to be_present
      expect(decoded['session_id']).to eq(session.id)
      expect(decoded['role']).to eq('parent')
    end

    it 'issues new refresh token' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { recoveryToken: recovery_token },
        context: context
      )

      refresh_token = result.dig('data', 'sessionByRecoveryToken', 'refreshToken')
      expect(refresh_token).to be_present

      # Verify refresh token works (with device fingerprint)
      device_fingerprint = Digest::SHA256.hexdigest("#{context[:user_agent]}#{context[:ip_address]}")
      result = Auth::TokenService.validate_refresh_token(
        refresh_token,
        device_fingerprint: device_fingerprint,
        ip_address: context[:ip_address],
        user_agent: context[:user_agent]
      )
      expect(result[:session]).to eq(session)
    end

    it 'creates audit log entry with device and IP' do
      DaybreakHealthBackendSchema.execute(
        query,
        variables: { recoveryToken: recovery_token },
        context: context
      )

      audit_log = AuditLog.where(action: 'SESSION_RECOVERED').last
      expect(audit_log).to be_present
      expect(audit_log.resource).to eq('OnboardingSession')
      expect(audit_log.resource_id).to eq(session.id)
      expect(audit_log.details['device']).to eq('Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)')
      expect(audit_log.details['ip']).to eq('192.168.1.1')
      expect(audit_log.ip_address).to eq('192.168.1.1')
      expect(audit_log.user_agent).to eq('Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)')
    end

    it 'preserves session progress' do
      original_progress = session.progress

      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { recoveryToken: recovery_token },
        context: context
      )

      recovered_progress = result.dig('data', 'sessionByRecoveryToken', 'session', 'progress')
      expect(recovered_progress).to eq(original_progress)
    end
  end

  describe 'one-time use' do
    it 'token cannot be reused' do
      # First use should succeed
      result1 = DaybreakHealthBackendSchema.execute(
        query,
        variables: { recoveryToken: recovery_token },
        context: context
      )

      expect(result1.dig('data', 'sessionByRecoveryToken')).to be_present

      # Second use should fail
      result2 = DaybreakHealthBackendSchema.execute(
        query,
        variables: { recoveryToken: recovery_token },
        context: context
      )

      expect(result2['errors']).to be_present
      expect(result2['errors'].first['message']).to include('Invalid or expired recovery token')
    end
  end

  describe 'error cases' do
    it 'returns error with invalid token' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { recoveryToken: 'invalid_token' },
        context: context
      )

      expect(result['errors']).to be_present
      expect(result['errors'].first['message']).to include('Invalid or expired recovery token')
    end

    it 'returns error when session is expired' do
      expired_session = create(:onboarding_session, :with_parent, status: :expired)
      expired_token = Auth::RecoveryTokenService.generate_recovery_token(
        session_id: expired_session.id,
        email: expired_session.parent.email
      )

      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { recoveryToken: expired_token },
        context: context
      )

      expect(result['errors']).to be_present
      expect(result['errors'].first['message']).to include('expired and cannot be recovered')
    end

    it 'returns error when session is abandoned' do
      abandoned_session = create(:onboarding_session, :with_parent, status: :abandoned)
      abandoned_token = Auth::RecoveryTokenService.generate_recovery_token(
        session_id: abandoned_session.id,
        email: abandoned_session.parent.email
      )

      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { recoveryToken: abandoned_token },
        context: context
      )

      expect(result['errors']).to be_present
      expect(result['errors'].first['message']).to include('abandoned and cannot be recovered')
    end
  end
end
