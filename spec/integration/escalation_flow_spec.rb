# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Escalation Flow Integration', type: :request do
  # Story 3.5: Human Escalation Request - End-to-End Integration Tests
  # Tests the complete escalation flow from detection to response
  let(:session) { create(:onboarding_session, status: :in_progress) }
  let(:token) { generate_session_token(session) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  before do
    # Set environment variables for contact options
    ENV['SUPPORT_PHONE'] = '1-800-DAYBREAK'
    ENV['SUPPORT_EMAIL'] = 'support@daybreakhealth.com'
    ENV['CHAT_HOURS'] = 'Monday-Friday 9am-5pm PT'
  end

  after do
    # Clean up environment variables
    ENV.delete('SUPPORT_PHONE')
    ENV.delete('SUPPORT_EMAIL')
    ENV.delete('CHAT_HOURS')
  end

  describe 'Automatic Escalation Detection via SendMessage' do
    # AC 3.5.8: AI detects escalation intent from phrases
    # AC 3.5.1: AI acknowledges empathetically
    # AC 3.5.2,3.5.3: Session flagged for human follow-up
    # AC 3.5.4: Contact options provided
    # AC 3.5.6: Care team notified
    # AC 3.5.10: Data preserved through escalation

    context 'when parent says "I want to talk to a real person"' do
      let(:mutation) do
        <<~GQL
          mutation SendMessage($sessionId: ID!, $content: String!) {
            sendMessage(sessionId: $sessionId, content: $content) {
              userMessage {
                id
                role
                content
              }
              assistantMessage {
                id
                role
                content
              }
              errors
            }
          }
        GQL
      end

      let(:variables) do
        {
          sessionId: "sess_#{session.id.gsub('-', '')}",
          content: "I want to talk to a real person"
        }
      end

      before do
        # Store some progress data to verify preservation
        session.update!(
          progress: {
            phase: 'parent_info',
            collected_fields: ['parent_first_name', 'parent_email'],
            parent_first_name: 'John Doe',
            parent_email: 'john@example.com'
          }
        )
      end

      it 'detects escalation intent and flags session' do
        expect {
          post '/graphql', params: { query: mutation, variables: variables }, headers: headers
        }.to change { session.reload.needs_human_contact }.from(false).to(true)
      end

      it 'sets escalation_requested_at timestamp' do
        post '/graphql', params: { query: mutation, variables: variables }, headers: headers
        expect(session.reload.escalation_requested_at).to be_present
        expect(session.reload.escalation_requested_at).to be_within(1.second).of(Time.current)
      end

      it 'enqueues escalation notification job' do
        expect {
          post '/graphql', params: { query: mutation, variables: variables }, headers: headers
        }.to have_enqueued_job(EscalationNotificationJob).with(session.id)
      end

      it 'creates audit log for automatic escalation detection' do
        expect {
          post '/graphql', params: { query: mutation, variables: variables }, headers: headers
        }.to change { AuditLog.where(action: 'ESCALATION_DETECTED').count }.by(1)

        audit_log = AuditLog.where(action: 'ESCALATION_DETECTED').last
        # EscalationDetector returns matched phrases like "real person", "talk to person"
        expect(audit_log.details['matched_phrases']).to include('real person')
        expect(audit_log.details['detection_method']).to eq('automatic')
      end

      it 'responds with empathetic escalation message including contact options' do
        post '/graphql', params: { query: mutation, variables: variables }, headers: headers
        json = JSON.parse(response.body)
        assistant_content = json['data']['sendMessage']['assistantMessage']['content']

        # AC 3.5.1: Empathetic acknowledgment
        expect(assistant_content).to match(/understand/i)

        # AC 3.5.4: Contact options included
        expect(assistant_content).to include('1-800-DAYBREAK')
        expect(assistant_content).to include('support@daybreakhealth.com')
        expect(assistant_content).to include('Monday-Friday 9am-5pm')
      end

      it 'preserves all session progress data' do
        # AC 3.5.10: Data preservation
        original_progress = session.progress.deep_dup

        post '/graphql', params: { query: mutation, variables: variables }, headers: headers

        session.reload
        expect(session.progress['phase']).to eq(original_progress['phase'])
        expect(session.progress['collected_fields']).to eq(original_progress['collected_fields'])
        expect(session.progress['parent_first_name']).to eq(original_progress['parent_first_name'])
        expect(session.progress['parent_email']).to eq(original_progress['parent_email'])
      end

      it 'stores both user and assistant messages' do
        expect {
          post '/graphql', params: { query: mutation, variables: variables }, headers: headers
        }.to change { session.messages.count }.by(2)

        user_message = session.messages.where(role: :user).last
        assistant_message = session.messages.where(role: :assistant).last

        expect(user_message.content).to eq("I want to talk to a real person")
        expect(assistant_message.content).to be_present
      end

      context 'when session is already escalated' do
        before do
          session.update!(
            needs_human_contact: true,
            escalation_requested_at: 1.hour.ago
          )
        end

        it 'does not create duplicate escalation' do
          expect {
            post '/graphql', params: { query: mutation, variables: variables }, headers: headers
          }.not_to change { session.reload.escalation_requested_at }
        end

        it 'does not enqueue duplicate notification job' do
          expect {
            post '/graphql', params: { query: mutation, variables: variables }, headers: headers
          }.not_to have_enqueued_job(EscalationNotificationJob)
        end
      end
    end

    context 'with different escalation trigger phrases' do
      [
        "I need to speak to a human",
        "Can I talk to a real person?",
        "This bot isn't helping, I need a representative",
        "I want human help",
        "Is there an actual person I can speak to?"
      ].each do |phrase|
        it "detects escalation for: #{phrase}" do
          variables = {
            sessionId: "sess_#{session.id.gsub('-', '')}",
            content: phrase
          }

          mutation = <<~GQL
            mutation SendMessage($sessionId: ID!, $content: String!) {
              sendMessage(sessionId: $sessionId, content: $content) {
                errors
              }
            }
          GQL

          expect {
            post '/graphql', params: { query: mutation, variables: variables }, headers: headers
          }.to change { session.reload.needs_human_contact }.from(false).to(true)
        end
      end
    end
  end

  describe 'Manual Escalation via RequestHumanContact Mutation' do
    # AC 3.5.2,3.5.3: Session flagged
    # AC 3.5.6: Care team notified
    # AC 3.5.7: Escalation reason captured
    # AC 3.5.10: Data preserved

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

    let(:variables) do
      {
        input: {
          sessionId: "sess_#{session.id.gsub('-', '')}",
          reason: "I need urgent help"
        }
      }
    end

    before do
      # Store some progress data to verify preservation
      session.update!(
        progress: {
          phase: 'child_info',
          collected_fields: ['child_first_name', 'child_age'],
          child_first_name: 'Emma',
          child_age: 10
        }
      )
    end

    it 'flags session for human contact' do
      post '/graphql', params: { query: mutation, variables: variables }, headers: headers
      json = JSON.parse(response.body)

      expect(json['data']['requestHumanContact']['success']).to be true
      expect(session.reload.needs_human_contact).to be true
    end

    it 'stores encrypted escalation reason' do
      post '/graphql', params: { query: mutation, variables: variables }, headers: headers

      session.reload
      expect(session.escalation_reason).to eq("I need urgent help")
    end

    it 'enqueues care team notification' do
      expect {
        post '/graphql', params: { query: mutation, variables: variables }, headers: headers
      }.to have_enqueued_job(EscalationNotificationJob).with(session.id)
    end

    it 'creates audit log for manual escalation' do
      expect {
        post '/graphql', params: { query: mutation, variables: variables }, headers: headers
      }.to change { AuditLog.where(action: 'HUMAN_ESCALATION_REQUESTED').count }.by(1)

      audit_log = AuditLog.where(action: 'HUMAN_ESCALATION_REQUESTED').last
      expect(audit_log.details['has_reason']).to be true
    end

    it 'preserves all session data' do
      # AC 3.5.10: Data preservation
      original_progress = session.progress.deep_dup

      post '/graphql', params: { query: mutation, variables: variables }, headers: headers

      session.reload
      expect(session.progress).to eq(original_progress)
    end

    context 'without escalation reason' do
      let(:variables) do
        {
          input: {
            sessionId: "sess_#{session.id.gsub('-', '')}"
          }
        }
      end

      it 'succeeds without requiring reason' do
        post '/graphql', params: { query: mutation, variables: variables }, headers: headers
        json = JSON.parse(response.body)

        expect(json['data']['requestHumanContact']['success']).to be true
        expect(session.reload.escalation_reason).to be_nil
      end
    end
  end

  describe 'Contact Options Query' do
    # AC 3.5.4: Contact options provided
    # AC 3.5.9: Option always visible/accessible

    let(:query) do
      <<~GQL
        query {
          contactOptions {
            phone
            email
            chatHours
          }
        }
      GQL
    end

    it 'returns contact options without authentication' do
      # Contact options should be publicly accessible
      post '/graphql', params: { query: query }
      json = JSON.parse(response.body)

      expect(json['data']['contactOptions']).to be_present
      expect(json['data']['contactOptions']['phone']).to eq('1-800-DAYBREAK')
      expect(json['data']['contactOptions']['email']).to eq('support@daybreakhealth.com')
      expect(json['data']['contactOptions']['chatHours']).to include('Monday-Friday')
    end
  end

  describe 'Session Subscription with Escalation Status' do
    # AC 3.5.9: Escalation status updates via subscription

    let(:query) do
      <<~GQL
        query GetSession($id: ID!) {
          session(id: $id) {
            id
            needsHumanContact
            escalationRequestedAt
          }
        }
      GQL
    end

    it 'includes escalation fields in session query' do
      session.update!(
        needs_human_contact: true,
        escalation_requested_at: Time.current
      )

      variables = { id: "sess_#{session.id.gsub('-', '')}" }
      post '/graphql', params: { query: query, variables: variables }, headers: headers
      json = JSON.parse(response.body)

      session_data = json['data']['session']
      expect(session_data['needsHumanContact']).to be true
      expect(session_data['escalationRequestedAt']).to be_present
    end
  end

  # Helper method to generate session token for auth
  def generate_session_token(session)
    Auth::JwtService.encode(
      { session_id: session.id },
      exp: 1.hour.from_now
    )
  end
end
