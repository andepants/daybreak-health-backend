# frozen_string_literal: true

require 'rails_helper'

# Alias for consistency with other specs
Errors = GraphqlErrors unless defined?(Errors)

RSpec.describe Mutations::Sessions::RequestHumanContact, type: :request do
  include ActiveJob::TestHelper

  describe 'requestHumanContact mutation' do
    let(:mutation) do
      <<~GQL
        mutation RequestHumanContact($input: RequestHumanContactInput!) {
          requestHumanContact(input: $input) {
            session {
              id
              needsHumanContact
              escalationRequestedAt
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

    # AC 3.5.2,3.5.3: GraphQL mutation requestHumanContact is implemented
    it 'is available in the GraphQL schema' do
      result = execute_mutation
      expect(result['errors']).to be_nil
    end

    # AC 3.5.2,3.5.3: Set needs_human_contact and escalation_requested_at
    context 'with valid authorization' do
      it 'requests human contact successfully' do
        result = execute_mutation

        expect(result['errors']).to be_nil
        data = result.dig('data', 'requestHumanContact')
        expect(data['success']).to be true
        expect(data.dig('session', 'needsHumanContact')).to be true
        expect(data.dig('session', 'escalationRequestedAt')).to be_present

        # Verify database update
        session.reload
        expect(session.needs_human_contact).to be true
        expect(session.escalation_requested_at).to be_present
      end

      it 'returns the session with escalation fields' do
        result = execute_mutation

        session_data = result.dig('data', 'requestHumanContact', 'session')
        expect(session_data['id']).to eq("sess_#{session.id.gsub('-', '')}")
        expect(session_data['needsHumanContact']).to be true
        expect(session_data['escalationRequestedAt']).to be_present
      end

      # AC 3.5.7: Escalation reason captured if provided
      it 'stores escalation reason when provided' do
        reason = 'I need urgent help with my child'
        vars = { input: { sessionId: session.id, reason: reason } }
        result = execute_mutation(vars: vars)

        expect(result['errors']).to be_nil
        session.reload
        expect(session.escalation_reason).to eq(reason)
      end

      it 'does not require escalation reason' do
        vars = { input: { sessionId: session.id } }
        result = execute_mutation(vars: vars)

        expect(result['errors']).to be_nil
        session.reload
        expect(session.escalation_reason).to be_nil
      end

      # AC 3.5.6: Audit log entry created
      it 'creates audit log entry with HUMAN_ESCALATION_REQUESTED action' do
        expect do
          execute_mutation
        end.to change { AuditLog.where(action: 'HUMAN_ESCALATION_REQUESTED').count }.by(1)

        audit_log = AuditLog.where(action: 'HUMAN_ESCALATION_REQUESTED').last
        expect(audit_log.resource).to eq('OnboardingSession')
        expect(audit_log.resource_id).to eq(session.id)
        expect(audit_log.details['has_reason']).to be false
      end

      it 'includes reason presence in audit log details' do
        vars = { input: { sessionId: session.id, reason: 'Need help' } }
        execute_mutation(vars: vars)

        audit_log = AuditLog.where(action: 'HUMAN_ESCALATION_REQUESTED').last
        expect(audit_log.details['has_reason']).to be true
      end

      # AC 3.5.6: Trigger notification job
      it 'enqueues escalation notification job' do
        expect do
          execute_mutation
        end.to have_enqueued_job(EscalationNotificationJob).with(session.id)
      end

      # AC 3.5.7: PHI encryption for escalation reason
      it 'encrypts escalation reason (PHI)' do
        reason = 'Personal sensitive information'
        vars = { input: { sessionId: session.id, reason: reason } }
        execute_mutation(vars: vars)

        session.reload
        # Raw database value should be encrypted
        raw_value = ActiveRecord::Base.connection.select_value(
          "SELECT escalation_reason FROM onboarding_sessions WHERE id = '#{session.id}'"
        )
        expect(raw_value).not_to eq(reason)
        expect(raw_value).not_to be_nil

        # But the model attribute should decrypt it
        expect(session.escalation_reason).to eq(reason)
      end
    end

    # Idempotency: Multiple escalation requests don't duplicate notifications
    context 'when session is already escalated' do
      let!(:escalated_session) do
        create(:onboarding_session,
               status: :started,
               needs_human_contact: true,
               escalation_requested_at: 1.hour.ago)
      end
      let(:token) { Auth::JwtService.encode({ session_id: escalated_session.id, role: 'anonymous' }) }
      let(:variables) { { input: { sessionId: escalated_session.id } } }

      it 'returns success without error' do
        result = execute_mutation

        expect(result['errors']).to be_nil
        data = result.dig('data', 'requestHumanContact')
        expect(data['success']).to be true
      end

      it 'does not create duplicate audit logs' do
        expect do
          execute_mutation
        end.not_to change { AuditLog.where(action: 'HUMAN_ESCALATION_REQUESTED').count }
      end

      it 'does not enqueue duplicate notification jobs' do
        expect do
          execute_mutation
        end.not_to have_enqueued_job(EscalationNotificationJob)
      end

      it 'preserves original escalation timestamp' do
        original_time = escalated_session.escalation_requested_at
        execute_mutation

        escalated_session.reload
        expect(escalated_session.escalation_requested_at).to be_within(1.second).of(original_time)
      end
    end

    # Authorization checks
    context 'authorization' do
      it 'rejects request without authentication token' do
        result = execute_mutation(hdrs: {})

        expect(result['errors']).not_to be_nil
        error = result['errors'].first
        expect(error['extensions']['code']).to eq(GraphqlErrors::ErrorCodes::FORBIDDEN)
      end

      it 'rejects request for another user\'s session' do
        other_session = create(:onboarding_session, status: :started)
        wrong_token = Auth::JwtService.encode({ session_id: other_session.id, role: 'anonymous' })

        result = execute_mutation(
          vars: { input: { sessionId: session.id } },
          hdrs: { 'Authorization' => "Bearer #{wrong_token}" }
        )

        expect(result['errors']).not_to be_nil
        error = result['errors'].first
        expect(error['message']).to include('do not have permission')
        expect(error['extensions']['code']).to eq(GraphqlErrors::ErrorCodes::FORBIDDEN)

        # Session should not be escalated
        session.reload
        expect(session.needs_human_contact).to be false
      end

      it 'rejects request with expired JWT token' do
        expired_token = Auth::JwtService.encode(
          { session_id: session.id, role: 'anonymous' },
          exp: 1.hour.ago
        )

        result = execute_mutation(hdrs: { 'Authorization' => "Bearer #{expired_token}" })

        expect(result['errors']).not_to be_nil
        error = result['errors'].first
        # Expired tokens result in nil current_user, which triggers authorization failure
        expect(error['extensions']['code']).to eq(GraphqlErrors::ErrorCodes::FORBIDDEN)
      end
    end

    # Error handling
    context 'error handling' do
      it 'returns NOT_FOUND error for non-existent session' do
        vars = { input: { sessionId: 'non-existent-id' } }
        result = execute_mutation(vars: vars)

        expect(result['errors']).not_to be_nil
        error = result['errors'].first
        expect(error['message']).to include('Session not found')
        expect(error['extensions']['code']).to eq(GraphqlErrors::ErrorCodes::NOT_FOUND)
      end

      it 'handles validation errors gracefully' do
        # Create session that violates validation (missing escalation_requested_at when needs_human_contact is true)
        # This shouldn't happen with the mutation logic, but test defensive handling
        allow_any_instance_of(OnboardingSession).to receive(:save!).and_raise(
          ActiveRecord::RecordInvalid.new(session)
        )

        result = execute_mutation

        expect(result['errors']).not_to be_nil
        error = result['errors'].first
        expect(error['message']).to include('Failed to request human contact')
        expect(error['extensions']['code']).to eq(GraphqlErrors::ErrorCodes::VALIDATION_ERROR)
      end
    end

    # AC 3.5.10: Data preservation - escalation doesn't lose any previously collected data
    context 'data preservation' do
      let!(:parent) { create(:parent, onboarding_session: session) }
      let!(:child) { create(:child, onboarding_session: session) }
      let!(:message) { create(:message, onboarding_session: session) }

      it 'preserves all session data after escalation' do
        execute_mutation

        session.reload
        expect(session.parent).to eq(parent)
        expect(session.child).to eq(child)
        expect(session.messages).to include(message)
      end

      it 'preserves session progress data' do
        session.update!(progress: { parent_info: true, child_info: true })
        execute_mutation

        session.reload
        expect(session.progress['parent_info']).to be true
        expect(session.progress['child_info']).to be true
      end
    end

    # Works across different session statuses
    context 'with different session statuses' do
      it 'allows escalation from started status' do
        session.update!(status: :started)
        result = execute_mutation

        expect(result['errors']).to be_nil
        expect(session.reload.needs_human_contact).to be true
      end

      it 'allows escalation from in_progress status' do
        session.update!(status: :in_progress)
        result = execute_mutation

        expect(result['errors']).to be_nil
        expect(session.reload.needs_human_contact).to be true
      end

      it 'allows escalation from insurance_pending status' do
        session.update!(status: :in_progress)
        session.update!(status: :insurance_pending)
        result = execute_mutation

        expect(result['errors']).to be_nil
        expect(session.reload.needs_human_contact).to be true
      end
    end
  end
end
