# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Sessions::RequestRecovery, type: :graphql do
  let(:redis) { Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')) }
  let(:session) { create(:onboarding_session, :with_parent, status: :in_progress) }
  let(:parent) { session.parent }
  let(:token) { Auth::JwtService.encode(session_id: session.id, role: 'parent') }
  let(:context) do
    {
      current_user: { session_id: session.id, role: 'parent' },
      ip_address: '192.168.1.1',
      user_agent: 'Mozilla/5.0'
    }
  end

  let(:mutation) do
    <<~GQL
      mutation RequestRecovery($sessionId: ID!) {
        requestSessionRecovery(input: { sessionId: $sessionId }) {
          success
          message
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

  describe 'successful recovery request' do
    it 'sends email when parent email exists' do
      expect {
        DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { sessionId: session.id },
          context: context
        )
      }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
        .with('ParentMailer', 'session_recovery', 'deliver_now', { args: anything })
    end

    it 'returns success response' do
      result = DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { sessionId: session.id },
        context: context
      )

      expect(result.dig('data', 'requestSessionRecovery', 'success')).to be true
      expect(result.dig('data', 'requestSessionRecovery', 'message')).to eq('Recovery link sent to your email')
    end

    it 'creates audit log entry' do
      DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { sessionId: session.id },
        context: context
      )

      audit_log = AuditLog.where(action: 'SESSION_RECOVERY_REQUESTED').last
      expect(audit_log).to be_present
      expect(audit_log.resource).to eq('OnboardingSession')
      expect(audit_log.resource_id).to eq(session.id)
      # PHI-safe: email should NOT be in audit log
      expect(audit_log.details['email']).to be_nil
      expect(audit_log.ip_address).to eq('192.168.1.1')
      expect(audit_log.user_agent).to eq('Mozilla/5.0')
    end

    it 'generates recovery token in Redis' do
      DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { sessionId: session.id },
        context: context
      )

      # Check that a recovery token was created in Redis
      keys = redis.keys('recovery:*')
      expect(keys).not_to be_empty
    end
  end

  describe 'error cases' do
    it 'fails when parent email not collected' do
      session_without_parent = create(:onboarding_session, status: :started)

      result = DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { sessionId: session_without_parent.id },
        context: context
      )

      expect(result['errors']).to be_present
      expect(result['errors'].first['message']).to include('Parent email not collected yet')
    end

    it 'fails when session not found' do
      result = DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { sessionId: 'nonexistent' },
        context: context
      )

      expect(result['errors']).to be_present
      expect(result['errors'].first['message']).to eq('Session not found')
    end

    it 'fails when session is expired' do
      expired_session = create(:onboarding_session, :with_parent, status: :expired)

      result = DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { sessionId: expired_session.id },
        context: context
      )

      expect(result['errors']).to be_present
      expect(result['errors'].first['message']).to include('expired and cannot be recovered')
    end

    it 'fails when session is abandoned' do
      abandoned_session = create(:onboarding_session, :with_parent, status: :abandoned)

      result = DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { sessionId: abandoned_session.id },
        context: context
      )

      expect(result['errors']).to be_present
      expect(result['errors'].first['message']).to include('abandoned and cannot be recovered')
    end

    it 'respects rate limits' do
      # Make 3 successful requests
      3.times do
        DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { sessionId: session.id },
          context: context
        )
      end

      # 4th request should fail
      result = DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { sessionId: session.id },
        context: context
      )

      expect(result['errors']).to be_present
      expect(result['errors'].first['message']).to include('Too many recovery requests')
    end
  end
end
