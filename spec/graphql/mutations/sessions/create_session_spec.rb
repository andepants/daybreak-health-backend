# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Sessions::CreateSession, type: :graphql do
  include ActiveSupport::Testing::TimeHelpers
  describe '.resolve' do
    let(:mutation) do
      <<~GQL
        mutation CreateSession($referralSource: String) {
          createSession(referralSource: $referralSource) {
            session {
              id
              status
              progress
              createdAt
              expiresAt
              referralSource
            }
            token
          }
        }
      GQL
    end

    context 'without referral source' do
      it 'creates a new session with started status' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: {},
          context: { ip_address: '127.0.0.1', user_agent: 'Test' }
        )

        expect(result['errors']).to be_nil
        data = result.dig('data', 'createSession')
        expect(data).to be_present

        session_data = data['session']
        expect(session_data['status']).to eq('started')
        expect(session_data['progress']).to eq({})
        expect(session_data['referralSource']).to be_nil
      end

      it 'generates session ID with sess_ prefix' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: {},
          context: { ip_address: '127.0.0.1', user_agent: 'Test' }
        )

        session_id = result.dig('data', 'createSession', 'session', 'id')
        expect(session_id).to match(/^sess_[a-f0-9]{32}$/)
      end

      it 'sets expires_at to 24 hours from creation' do
        now = Time.current
        travel_to(now) do
          result = DaybreakHealthBackendSchema.execute(
            mutation,
            variables: {},
            context: { ip_address: '127.0.0.1', user_agent: 'Test' }
          )

          expires_at = Time.zone.parse(result.dig('data', 'createSession', 'session', 'expiresAt'))
          expected_expiry = now + 24.hours
          expect(expires_at).to be_within(1.second).of(expected_expiry)
        end
      end

      it 'returns a JWT token' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: {},
          context: { ip_address: '127.0.0.1', user_agent: 'Test' }
        )

        token = result.dig('data', 'createSession', 'token')
        expect(token).to be_present
        expect(token.split('.').length).to eq(3) # JWT has 3 parts
      end

      it 'JWT token contains session_id and role' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: {},
          context: { ip_address: '127.0.0.1', user_agent: 'Test' }
        )

        token = result.dig('data', 'createSession', 'token')
        session_id_with_prefix = result.dig('data', 'createSession', 'session', 'id')

        payload = Auth::JwtService.decode(token)
        # JWT contains actual UUID, not the sess_ prefixed version
        expect(payload['session_id']).to be_present
        expect(payload['session_id']).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
        # Verify the JWT session_id matches the GraphQL ID (when converted)
        jwt_id_with_prefix = "sess_#{payload['session_id'].gsub('-', '')}"
        expect(jwt_id_with_prefix).to eq(session_id_with_prefix)
        expect(payload['role']).to eq('anonymous')
      end

      it 'JWT token expires in 1 hour by default' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: {},
          context: { ip_address: '127.0.0.1', user_agent: 'Test' }
        )

        token = result.dig('data', 'createSession', 'token')
        payload = Auth::JwtService.decode(token)

        exp_time = Time.at(payload['exp'])
        iat_time = Time.at(payload['iat'])
        duration = exp_time - iat_time

        expect(duration).to be_within(1).of(1.hour.to_i)
      end

      it 'creates an audit log entry' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: {},
          context: { ip_address: '127.0.0.1', user_agent: 'Test' }
        )

        session_id = result.dig('data', 'createSession', 'session', 'id')
        # Convert sess_ prefixed ID back to UUID format for lookup
        uuid = session_id.sub('sess_', '')
        uuid_formatted = "#{uuid[0..7]}-#{uuid[8..11]}-#{uuid[12..15]}-#{uuid[16..19]}-#{uuid[20..31]}"

        # Find the audit log for this specific session
        audit = AuditLog.find_by(
          action: 'SESSION_CREATED',
          resource_id: uuid_formatted
        )

        expect(audit).to be_present
        expect(audit.resource).to eq('OnboardingSession')
        expect(audit.ip_address).to eq('127.0.0.1')
        expect(audit.user_agent).to eq('Test')
      end
    end

    context 'with referral_source' do
      it 'creates session with referral_source' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { referralSource: 'instagram' },
          context: { ip_address: '127.0.0.1', user_agent: 'Test' }
        )

        session_data = result.dig('data', 'createSession', 'session')
        expect(session_data['referralSource']).to eq('instagram')
      end
    end

    context 'with custom token expiration' do
      around do |example|
        original_value = ENV['SESSION_TOKEN_EXPIRATION_HOURS']
        ENV['SESSION_TOKEN_EXPIRATION_HOURS'] = '2'
        example.run
        ENV['SESSION_TOKEN_EXPIRATION_HOURS'] = original_value
      end

      it 'uses configured token expiration' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: {},
          context: { ip_address: '127.0.0.1', user_agent: 'Test' }
        )

        token = result.dig('data', 'createSession', 'token')
        payload = Auth::JwtService.decode(token)

        exp_time = Time.at(payload['exp'])
        iat_time = Time.at(payload['iat'])
        duration = exp_time - iat_time

        expect(duration).to be_within(1).of(2.hours.to_i)
      end
    end
  end
end
