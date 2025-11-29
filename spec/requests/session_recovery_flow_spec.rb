# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Session Recovery Flow', type: :request do
  let(:redis) { Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')) }

  before do
    redis.flushdb
  end

  after do
    redis.flushdb
  end

  describe 'full recovery flow' do
    it 'allows parent to recover session from different device' do
      # Step 1: Create session
      create_mutation = <<~GQL
        mutation {
          createSession {
            session { id status }
            token
          }
        }
      GQL

      create_result = DaybreakHealthBackendSchema.execute(create_mutation)

      session_id = create_result.dig('data', 'createSession', 'session', 'id')
      token = create_result.dig('data', 'createSession', 'token')

      expect(session_id).to be_present
      expect(token).to be_present

      # Step 2: Collect parent email (simplified - would normally be part of intake flow)
      # Strip sess_ prefix and convert back to UUID format
      actual_id = if session_id.start_with?('sess_')
        hex = session_id.sub('sess_', '')
        # Convert 32-char hex to UUID format: 8-4-4-4-12
        "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
      else
        session_id
      end
      session = OnboardingSession.find(actual_id)
      parent = create(:parent, onboarding_session: session, email: 'parent@example.com')

      # Step 3: Request recovery
      request_mutation = <<~GQL
        mutation RequestRecovery($sessionId: ID!) {
          requestSessionRecovery(input: { sessionId: $sessionId }) {
            success
            message
          }
        }
      GQL

      request_context = {
        current_user: { session_id: session_id, role: 'parent' },
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0 (iPhone)'
      }

      request_result = DaybreakHealthBackendSchema.execute(
        request_mutation,
        variables: { sessionId: actual_id },  # Use actual UUID, not sess_ prefixed ID
        context: request_context
      )

      expect(request_result.dig('data', 'requestSessionRecovery', 'success')).to be true

      # Step 4: Extract token from Redis (simulating email click)
      recovery_tokens = redis.keys('recovery:*')
      expect(recovery_tokens).not_to be_empty
      recovery_token = recovery_tokens.first.sub('recovery:', '')

      # Step 5: Recover session from different device
      recovery_query = <<~GQL
        query SessionByRecoveryToken($recoveryToken: String!) {
          sessionByRecoveryToken(recoveryToken: $recoveryToken) {
            session { id status }
            token
            refreshToken
          }
        }
      GQL

      recovery_context = {
        ip_address: '10.0.0.1',
        user_agent: 'Mozilla/5.0 (Macintosh)'
      }

      recovery_result = DaybreakHealthBackendSchema.execute(
        recovery_query,
        variables: { recoveryToken: recovery_token },
        context: recovery_context
      )

      # Verify recovery successful
      expect(recovery_result.dig('data', 'sessionByRecoveryToken', 'session', 'id')).to eq(session_id)
      new_token = recovery_result.dig('data', 'sessionByRecoveryToken', 'token')
      new_refresh_token = recovery_result.dig('data', 'sessionByRecoveryToken', 'refreshToken')

      expect(new_token).to be_present
      expect(new_refresh_token).to be_present

      # Verify audit logs created
      audit_logs = AuditLog.where(resource_id: actual_id).order(:created_at)
      expect(audit_logs.pluck(:action)).to include('SESSION_RECOVERY_REQUESTED', 'SESSION_RECOVERED')

      recovery_log = audit_logs.find_by(action: 'SESSION_RECOVERED')
      expect(recovery_log.details['device']).to eq('Mozilla/5.0 (Macintosh)')
      expect(recovery_log.details['ip']).to eq('10.0.0.1')
    end
  end

  describe 'one-time use enforcement' do
    it 'prevents token reuse' do
      session = create(:onboarding_session, :with_parent, status: :in_progress)
      parent = session.parent

      # Generate recovery token
      recovery_token = Auth::RecoveryTokenService.generate_recovery_token(
        session_id: session.id,
        email: parent.email
      )

      recovery_query = <<~GQL
        query SessionByRecoveryToken($recoveryToken: String!) {
          sessionByRecoveryToken(recoveryToken: $recoveryToken) {
            session { id }
            token
          }
        }
      GQL

      context = {
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0'
      }

      # First use succeeds
      result1 = DaybreakHealthBackendSchema.execute(
        recovery_query,
        variables: { recoveryToken: recovery_token },
        context: context
      )
      expect(result1.dig('data', 'sessionByRecoveryToken')).to be_present

      # Second use fails
      result2 = DaybreakHealthBackendSchema.execute(
        recovery_query,
        variables: { recoveryToken: recovery_token },
        context: context
      )
      expect(result2['errors']).to be_present
      expect(result2['errors'].first['message']).to include('Invalid or expired')
    end
  end

  describe 'token expiration' do
    it 'rejects expired tokens' do
      session = create(:onboarding_session, :with_parent, status: :in_progress)
      parent = session.parent

      # Generate recovery token
      recovery_token = Auth::RecoveryTokenService.generate_recovery_token(
        session_id: session.id,
        email: parent.email
      )

      # Simulate expiration by deleting from Redis
      redis.del("recovery:#{recovery_token}")

      recovery_query = <<~GQL
        query SessionByRecoveryToken($recoveryToken: String!) {
          sessionByRecoveryToken(recoveryToken: $recoveryToken) {
            session { id }
            token
          }
        }
      GQL

      context = {
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0'
      }

      result = DaybreakHealthBackendSchema.execute(
        recovery_query,
        variables: { recoveryToken: recovery_token },
        context: context
      )

      expect(result['errors']).to be_present
      expect(result['errors'].first['message']).to include('Invalid or expired')
    end
  end

  describe 'multi-device support' do
    it 'allows multiple active devices simultaneously' do
      session = create(:onboarding_session, :with_parent, status: :in_progress)
      parent = session.parent

      # Device 1: Get initial token
      token1 = Auth::JwtService.encode({ session_id: session.id, role: 'parent' })

      # Device 2: Request recovery
      recovery_token = Auth::RecoveryTokenService.generate_recovery_token(
        session_id: session.id,
        email: parent.email
      )

      # Device 2: Recover session
      recovery_query = <<~GQL
        query SessionByRecoveryToken($recoveryToken: String!) {
          sessionByRecoveryToken(recoveryToken: $recoveryToken) {
            token
          }
        }
      GQL

      result = DaybreakHealthBackendSchema.execute(
        recovery_query,
        variables: { recoveryToken: recovery_token },
        context: { ip_address: '10.0.0.1', user_agent: 'Device 2' }
      )

      token2 = result.dig('data', 'sessionByRecoveryToken', 'token')

      # Both tokens should be valid
      expect(Auth::JwtService.valid?(token1)).to be true
      expect(Auth::JwtService.valid?(token2)).to be true

      # Both tokens should decode to same session
      payload1 = Auth::JwtService.decode(token1)
      payload2 = Auth::JwtService.decode(token2)

      expect(payload1['session_id']).to eq(session.id)
      expect(payload2['session_id']).to eq(session.id)
    end
  end

  describe 'rate limiting' do
    it 'enforces rate limits across multiple recovery requests' do
      session = create(:onboarding_session, :with_parent, status: :in_progress)
      parent = session.parent

      request_mutation = <<~GQL
        mutation RequestRecovery($sessionId: ID!) {
          requestSessionRecovery(input: { sessionId: $sessionId }) {
            success
          }
        }
      GQL

      context = {
        current_user: { session_id: session.id, role: 'parent' },
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0'
      }

      # First 3 requests succeed
      3.times do
        result = DaybreakHealthBackendSchema.execute(
          request_mutation,
          variables: { sessionId: session.id },
          context: context
        )
        expect(result.dig('data', 'requestSessionRecovery', 'success')).to be true
      end

      # 4th request fails
      result = DaybreakHealthBackendSchema.execute(
        request_mutation,
        variables: { sessionId: session.id },
        context: context
      )

      expect(result['errors']).to be_present
      expect(result['errors'].first['message']).to include('Too many recovery requests')
    end
  end

  describe 'session state validation' do
    it 'prevents recovery of expired sessions' do
      session = create(:onboarding_session, :with_parent, status: :expired)
      parent = session.parent

      request_mutation = <<~GQL
        mutation RequestRecovery($sessionId: ID!) {
          requestSessionRecovery(input: { sessionId: $sessionId }) {
            success
          }
        }
      GQL

      context = {
        current_user: { session_id: session.id, role: 'parent' },
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0'
      }

      result = DaybreakHealthBackendSchema.execute(
        request_mutation,
        variables: { sessionId: session.id },
        context: context
      )

      expect(result['errors']).to be_present
      expect(result['errors'].first['message']).to include('expired and cannot be recovered')
    end

    it 'prevents recovery of abandoned sessions' do
      session = create(:onboarding_session, :with_parent, status: :abandoned)
      parent = session.parent

      request_mutation = <<~GQL
        mutation RequestRecovery($sessionId: ID!) {
          requestSessionRecovery(input: { sessionId: $sessionId }) {
            success
          }
        }
      GQL

      context = {
        current_user: { session_id: session.id, role: 'parent' },
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0'
      }

      result = DaybreakHealthBackendSchema.execute(
        request_mutation,
        variables: { sessionId: session.id },
        context: context
      )

      expect(result['errors']).to be_present
      expect(result['errors'].first['message']).to include('abandoned and cannot be recovered')
    end
  end
end
