# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscriptions::MessageReceived, type: :graphql do
  let(:session) { create(:onboarding_session) }
  let(:other_session) { create(:onboarding_session) }
  let(:mock_channel) { instance_double(ActionCable::Channel::Base, stream_from: true) }

  let(:subscription) do
    <<~GQL
      subscription MessageReceived($sessionId: ID!) {
        messageReceived(sessionId: $sessionId) {
          id
          role
          content
          createdAt
        }
      }
    GQL
  end

  describe '#subscribe' do
    context 'with valid authentication' do
      it 'allows subscription to own session' do
        result = execute_graphql(
          subscription,
          variables: { sessionId: "sess_#{session.id.delete('-')}" },
          context: { channel: mock_channel, current_session_id: session.id }
        )

        expect(result['errors']).to be_nil
      end
    end

    context 'without authentication' do
      it 'rejects subscription without current_session_id' do
        result = execute_graphql(
          subscription,
          variables: { sessionId: "sess_#{session.id.delete('-')}" },
          context: { channel: mock_channel }
        )

        expect(result['errors']).to be_present
        expect(result['errors'].first['message']).to eq('Authentication required')
      end

      it 'rejects subscription with nil current_session_id' do
        result = execute_graphql(
          subscription,
          variables: { sessionId: "sess_#{session.id.delete('-')}" },
          context: { channel: mock_channel, current_session_id: nil }
        )

        expect(result['errors']).to be_present
        expect(result['errors'].first['message']).to eq('Authentication required')
      end
    end

    context 'HIPAA compliance - cross-session access prevention' do
      it 'rejects subscription to another users session' do
        result = execute_graphql(
          subscription,
          variables: { sessionId: "sess_#{other_session.id.delete('-')}" },
          context: { channel: mock_channel, current_session_id: session.id }
        )

        expect(result['errors']).to be_present
        expect(result['errors'].first['message']).to eq('Unauthorized access to session')
      end

      it 'logs unauthorized access attempts' do
        expect(Rails.logger).to receive(:warn).with(/Unauthorized subscription attempt/)

        execute_graphql(
          subscription,
          variables: { sessionId: "sess_#{other_session.id.delete('-')}" },
          context: { channel: mock_channel, current_session_id: session.id }
        )
      end
    end

    context 'with non-existent session' do
      it 'returns session not found error' do
        fake_uuid = SecureRandom.uuid
        result = execute_graphql(
          subscription,
          variables: { sessionId: "sess_#{fake_uuid.delete('-')}" },
          context: { channel: mock_channel, current_session_id: session.id }
        )

        expect(result['errors']).to be_present
        expect(result['errors'].first['message']).to eq('Session not found')
      end
    end
  end

  describe 'session_id format handling' do
    it 'handles session_id with sess_ prefix and no dashes' do
      result = execute_graphql(
        subscription,
        variables: { sessionId: "sess_#{session.id.delete('-')}" },
        context: { channel: mock_channel, current_session_id: session.id }
      )

      expect(result['errors']).to be_nil
    end

    it 'handles session_id with sess_ prefix and dashes' do
      result = execute_graphql(
        subscription,
        variables: { sessionId: "sess_#{session.id}" },
        context: { channel: mock_channel, current_session_id: session.id }
      )

      expect(result['errors']).to be_nil
    end
  end
end
