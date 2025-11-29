# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Sessions::AbandonSession, type: :request do
  describe 'abandonSession mutation' do
    let(:mutation) do
      <<~GQL
        mutation AbandonSession($input: AbandonSessionInput!) {
          abandonSession(input: $input) {
            session {
              id
              status
            }
            success
          }
        }
      GQL
    end

    let(:session) { create(:onboarding_session, status: :started) }
    let(:variables) { { input: { sessionId: session.id } } }
    let(:token) { Auth::JwtService.encode({ session_id: session.id, role: 'anonymous' }) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    def execute_mutation(vars: variables, hdrs: headers)
      post '/graphql', params: { query: mutation, variables: vars }, headers: hdrs
      JSON.parse(response.body)
    end

    # AC 2.5.1: GraphQL mutation abandonSession(sessionId: ID!): Session! is implemented
    it 'is available in the GraphQL schema' do
      result = execute_mutation
      expect(result['errors']).to be_nil
    end

    # AC 2.5.3: Mutation sets session status to ABANDONED
    # AC 2.5.7: Response confirms abandonment with session ID and new status
    context 'with valid authorization' do
      it 'abandons the session successfully' do
        result = execute_mutation

        expect(result['errors']).to be_nil
        data = result.dig('data', 'abandonSession')
        expect(data['success']).to be true
        # ID is returned with sess_ prefix and no hyphens
        expect(data.dig('session', 'id')).to eq("sess_#{session.id.gsub('-', '')}")
        expect(data.dig('session', 'status')).to eq('abandoned')

        # Verify database update
        expect(session.reload.status).to eq('abandoned')
      end

      it 'returns the session with updated status' do
        result = execute_mutation

        session_data = result.dig('data', 'abandonSession', 'session')
        # ID is returned with sess_ prefix and no hyphens
        expect(session_data['id']).to eq("sess_#{session.id.gsub('-', '')}")
        expect(session_data['status']).to eq('abandoned')
      end
    end

    # AC 2.5.2: Mutation requires valid session token (cannot abandon others' sessions)
    context 'authorization checks' do
      it 'rejects abandonment without authentication token' do
        result = execute_mutation(hdrs: {})

        # Should fail authorization (no current_user in context)
        # BaseMutation's authorize method will raise Pundit::NotAuthorizedError
        # which the schema converts to FORBIDDEN error
        expect(result['errors']).not_to be_nil
        error = result['errors'].first
        expect(error['extensions']['code']).to eq(Errors::ErrorCodes::FORBIDDEN)
      end

      it 'rejects abandonment of another user\'s session' do
        other_session = create(:onboarding_session, status: :started)
        wrong_token = Auth::JwtService.encode({ session_id: other_session.id, role: 'anonymous' })

        result = execute_mutation(
          vars: { input: { sessionId: session.id } },
          hdrs: { 'Authorization' => "Bearer #{wrong_token}" }
        )

        expect(result['errors']).not_to be_nil
        error = result['errors'].first
        expect(error['message']).to include('do not have permission')
        expect(error['extensions']['code']).to eq(Errors::ErrorCodes::FORBIDDEN)

        # Session should not be abandoned
        expect(session.reload.status).to eq('started')
      end

      it 'rejects abandonment with expired JWT token' do
        expired_token = Auth::JwtService.encode(
          { session_id: session.id, role: 'anonymous' },
          exp: 1.hour.ago
        )

        result = execute_mutation(hdrs: { 'Authorization' => "Bearer #{expired_token}" })

        expect(result['errors']).not_to be_nil
        expect(session.reload.status).to eq('started')
      end
    end

    # AC 2.5.4: Session data is retained per data retention policy (same as expiration)
    context 'data retention' do
      let(:session_with_data) do
        create(:onboarding_session, status: :in_progress).tap do |s|
          create(:parent, onboarding_session: s, email: 'parent@example.com')
          create(:child, onboarding_session: s, first_name: 'Test')
          create(:message, onboarding_session: s, content: 'Hello')
        end
      end
      let(:token_with_data) { Auth::JwtService.encode({ session_id: session_with_data.id, role: 'anonymous' }) }

      it 'retains all session data after abandonment' do
        execute_mutation(
          vars: { input: { sessionId: session_with_data.id } },
          hdrs: { 'Authorization' => "Bearer #{token_with_data}" }
        )

        session_with_data.reload

        # Session data should still exist
        expect(session_with_data.parent).to be_present
        expect(session_with_data.child).to be_present
        expect(session_with_data.messages.count).to eq(1)
        expect(session_with_data.progress).not_to be_nil
      end

      it 'does not delete session record' do
        session_id = session_with_data.id

        execute_mutation(
          vars: { input: { sessionId: session_id } },
          hdrs: { 'Authorization' => "Bearer #{token_with_data}" }
        )

        expect(OnboardingSession.exists?(session_id)).to be true
      end
    end

    # AC 2.5.8: Audit log entry created: action: SESSION_ABANDONED, details: { previousStatus }
    context 'audit logging' do
      it 'creates audit log entry with SESSION_ABANDONED action' do
        # Note: Auditable concern creates UPDATE audit log, plus SESSION_ABANDONED
        expect do
          execute_mutation
        end.to change(AuditLog, :count).by_at_least(1)

        # Find the SESSION_ABANDONED audit log
        abandonment_log = AuditLog.where(action: 'SESSION_ABANDONED').last
        expect(abandonment_log).to be_present
        expect(abandonment_log.onboarding_session_id).to eq(session.id)
        expect(abandonment_log.resource).to eq('OnboardingSession')
      end

      it 'includes previous status in audit log details' do
        session.update!(status: :in_progress)

        execute_mutation

        abandonment_log = AuditLog.where(action: 'SESSION_ABANDONED').last
        expect(abandonment_log.details['previousStatus']).to eq('in_progress')
      end

      it 'records IP address in audit log' do
        # Make request and verify IP is captured
        # Note: In test environment, remote_ip is typically 127.0.0.1 or set by test headers
        execute_mutation

        abandonment_log = AuditLog.where(action: 'SESSION_ABANDONED').last
        # Verify IP address field exists (actual IP may vary in test environment)
        expect(abandonment_log.ip_address).to be_present
      end

      it 'records user agent in audit log' do
        custom_headers = headers.merge('User-Agent' => 'Mozilla/5.0 Test Browser')

        execute_mutation(hdrs: custom_headers)

        abandonment_log = AuditLog.where(action: 'SESSION_ABANDONED').last
        expect(abandonment_log.user_agent).to eq('Mozilla/5.0 Test Browser')
      end
    end

    # Idempotency test (from tech spec)
    context 'idempotency' do
      it 'succeeds when abandoning already abandoned session' do
        session.update!(status: :abandoned)

        result = execute_mutation

        expect(result['errors']).to be_nil
        data = result.dig('data', 'abandonSession')
        expect(data['success']).to be true
        expect(data.dig('session', 'status')).to eq('abandoned')
      end

      it 'does not create duplicate audit logs for already abandoned session' do
        session.update!(status: :abandoned)

        expect do
          execute_mutation
        end.not_to change(AuditLog, :count)
      end
    end

    # AC 2.5.5: Parent can create a new session immediately after abandonment
    context 'new session creation after abandonment' do
      it 'allows creating a new session after abandoning previous one' do
        # Abandon first session
        execute_mutation

        # Create new session (via CreateSession mutation)
        create_mutation = <<~GQL
          mutation {
            createSession {
              session { id status }
              token
            }
          }
        GQL

        post '/graphql', params: { query: create_mutation }
        result = JSON.parse(response.body)

        expect(result['errors']).to be_nil
        new_session_data = result.dig('data', 'createSession', 'session')
        expect(new_session_data['status']).to eq('started')
        # Don't compare IDs directly since they use different formats
        expect(new_session_data['id']).not_to eq("sess_#{session.id.gsub('-', '')}")
      end
    end

    # AC 2.5.6: Abandoned session cannot be resumed (mutation returns error if attempted)
    context 'preventing operations on abandoned sessions' do
      before do
        execute_mutation # Abandon the session
      end

      it 'prevents updating progress on abandoned session' do
        update_mutation = <<~GQL
          mutation UpdateProgress($input: UpdateSessionProgressInput!) {
            updateSessionProgress(input: $input) {
              session { id }
            }
          }
        GQL

        post '/graphql',
             params: {
               query: update_mutation,
               variables: {
                 input: {
                   sessionId: session.id,
                   progress: { currentStep: 'test' }
                 }
               }
             },
             headers: headers

        result = JSON.parse(response.body)

        expect(result['errors']).not_to be_nil
        error = result['errors'].first
        expect(error['message']).to include('abandoned')
        expect(error['extensions']['code']).to eq(Errors::ErrorCodes::SESSION_ABANDONED)
      end
    end

    # State transition tests
    context 'state transitions' do
      it 'can abandon session from started status' do
        session.update!(status: :started)
        result = execute_mutation

        expect(result.dig('data', 'abandonSession', 'session', 'status')).to eq('abandoned')
      end

      it 'can abandon session from in_progress status' do
        # Transition: started -> in_progress
        session.update!(status: :in_progress)
        result = execute_mutation

        expect(result.dig('data', 'abandonSession', 'session', 'status')).to eq('abandoned')
      end

      it 'can abandon session from insurance_pending status' do
        # Valid transition path: started -> in_progress -> insurance_pending
        session.update!(status: :in_progress)
        session.update!(status: :insurance_pending)
        result = execute_mutation

        expect(result.dig('data', 'abandonSession', 'session', 'status')).to eq('abandoned')
      end

      it 'can abandon session from assessment_complete status' do
        # Valid transition path: started -> in_progress -> insurance_pending -> assessment_complete
        session.update!(status: :in_progress)
        session.update!(status: :insurance_pending)
        session.update!(status: :assessment_complete)
        result = execute_mutation

        expect(result.dig('data', 'abandonSession', 'session', 'status')).to eq('abandoned')
      end
    end

    # Error handling
    context 'error scenarios' do
      it 'returns NOT_FOUND error for non-existent session' do
        result = execute_mutation(vars: { input: { sessionId: 'non-existent-id' } })

        expect(result['errors']).not_to be_nil
        error = result['errors'].first
        expect(error['extensions']['code']).to eq(Errors::ErrorCodes::NOT_FOUND)
      end
    end
  end
end
