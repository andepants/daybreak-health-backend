# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Conversation::SendMessage, type: :graphql do
  let(:session) { create(:onboarding_session, status: :in_progress) }
  let(:session_id) { "sess_#{session.id.gsub('-', '')}" }
  let(:context) { { current_session_id: session.id } }

  let(:mock_ai_client) { instance_double(Ai::Client) }
  let(:ai_response) do
    {
      content: "Thank you for sharing that. I understand.",
      role: "assistant",
      provider: "anthropic"
    }
  end

  before do
    # Mock AI client to avoid actual API calls in tests
    allow(Ai::Client).to receive(:new).and_return(mock_ai_client)
    allow(mock_ai_client).to receive(:chat).and_return(ai_response)
  end

  describe 'Story 3.3: Help & Off-Topic Handling Integration' do
    let(:mutation) do
      <<~GQL
        mutation($sessionId: ID!, $content: String!) {
          sendMessage(sessionId: $sessionId, content: $content) {
            userMessage {
              id
              role
              content
              metadata
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

    context 'help request flow' do
      it 'classifies "I don\'t understand" as help_request' do
        variables = {
          sessionId: session_id,
          content: "I don't understand what you're asking"
        }

        result = execute_graphql(mutation, variables: variables, context: context)
        user_message = result.dig('data', 'sendMessage', 'userMessage')

        expect(user_message['metadata']['intent']).to eq('help_request')
        expect(user_message['metadata']['intent_confidence']).to be > 0.8
      end

      it 'enters help mode when help request detected' do
        variables = {
          sessionId: session_id,
          content: "Why do you need my email?"
        }

        execute_graphql(mutation, variables: variables, context: context)

        session.reload
        context_state = session.progress.dig('context_manager', 'conversation_state')
        expect(context_state).to eq('help')
      end

      it 'stores help context with field information' do
        variables = {
          sessionId: session_id,
          content: "What does date of birth mean?"
        }

        execute_graphql(mutation, variables: variables, context: context)

        session.reload
        help_context = session.progress.dig('context_manager', 'help_context')
        expect(help_context).to be_present
        expect(help_context['field']).to eq('date_of_birth')
      end

      it 'returns to intake mode after help request is addressed' do
        # First message: help request
        execute_graphql(mutation,
          variables: { sessionId: session_id, content: "I'm confused" },
          context: context
        )

        session.reload
        expect(session.progress.dig('context_manager', 'conversation_state')).to eq('help')

        # Second message: answer (assumes help was addressed)
        execute_graphql(mutation,
          variables: { sessionId: session_id, content: "sarah@email.com" },
          context: context
        )

        session.reload
        expect(session.progress.dig('context_manager', 'conversation_state')).to eq('intake')
      end

      it 'logs help interaction for analytics' do
        variables = {
          sessionId: session_id,
          content: "I don't understand"
        }

        expect {
          execute_graphql(mutation, variables: variables, context: context)
        }.to change { AuditLog.where(action: 'HELP_REQUEST').count }.by(1)

        help_log = AuditLog.where(action: 'HELP_REQUEST').last
        expect(help_log.details['intent']).to eq('help_request')
        expect(help_log.details['confidence']).to be_present
      end
    end

    context 'off-topic flow' do
      it 'classifies cost questions as off_topic' do
        variables = {
          sessionId: session_id,
          content: "How much does this cost?"
        }

        result = execute_graphql(mutation, variables: variables, context: context)
        user_message = result.dig('data', 'sendMessage', 'userMessage')

        expect(user_message['metadata']['intent']).to eq('off_topic')
      end

      it 'enters off-topic mode when off-topic detected' do
        variables = {
          sessionId: session_id,
          content: "What are your hours?"
        }

        execute_graphql(mutation, variables: variables, context: context)

        session.reload
        context_state = session.progress.dig('context_manager', 'conversation_state')
        expect(context_state).to eq('off_topic')
      end

      it 'increments off-topic count' do
        initial_count = session.progress&.dig('context_manager', 'off_topic_count') || 0

        execute_graphql(mutation,
          variables: { sessionId: session_id, content: "How much does this cost?" },
          context: context
        )

        session.reload
        new_count = session.progress.dig('context_manager', 'off_topic_count')
        expect(new_count).to eq(initial_count + 1)
      end

      it 'categorizes cost questions correctly' do
        variables = {
          sessionId: session_id,
          content: "How much will I have to pay?"
        }

        execute_graphql(mutation, variables: variables, context: context)

        session.reload
        last_off_topic = session.progress.dig('context_manager', 'last_off_topic')
        expect(last_off_topic['topic']).to eq('cost_concern')
      end

      it 'returns to intake mode after off-topic is addressed' do
        # Off-topic question
        execute_graphql(mutation,
          variables: { sessionId: session_id, content: "Where are you located?" },
          context: context
        )

        session.reload
        expect(session.progress.dig('context_manager', 'conversation_state')).to eq('off_topic')

        # Answer to intake question
        execute_graphql(mutation,
          variables: { sessionId: session_id, content: "John Smith" },
          context: context
        )

        session.reload
        expect(session.progress.dig('context_manager', 'conversation_state')).to eq('intake')
      end
    end

    context 'question vs answer classification' do
      it 'correctly distinguishes question from answer' do
        # Question
        result = execute_graphql(mutation,
          variables: { sessionId: session_id, content: "What happens next?" },
          context: context
        )

        user_message = result.dig('data', 'sendMessage', 'userMessage')
        expect([:question, :clarification]).to include(user_message['metadata']['intent'].to_sym)

        # Answer
        result = execute_graphql(mutation,
          variables: { sessionId: session_id, content: "sarah@email.com" },
          context: context
        )

        user_message = result.dig('data', 'sendMessage', 'userMessage')
        expect(user_message['metadata']['intent']).to eq('answer')
      end
    end

    context 'conversation flow recovery' do
      it 'maintains conversation context through help → intake transition' do
        # Help request
        execute_graphql(mutation,
          variables: { sessionId: session_id, content: "Why do you need this?" },
          context: context
        )

        session.reload
        expect(session.progress.dig('context_manager', 'conversation_state')).to eq('help')

        # Answer after help
        execute_graphql(mutation,
          variables: { sessionId: session_id, content: "Sarah Johnson" },
          context: context
        )

        session.reload
        expect(session.progress.dig('context_manager', 'conversation_state')).to eq('intake')

        # Verify context wasn't lost
        expect(session.progress.dig('context_manager', 'phase')).to be_present
      end

      it 'maintains off-topic count across multiple redirections' do
        3.times do |i|
          execute_graphql(mutation,
            variables: { sessionId: session_id, content: "How much does this cost?" },
            context: context
          )

          # Return to intake
          execute_graphql(mutation,
            variables: { sessionId: session_id, content: "Information #{i}" },
            context: context
          )
        end

        session.reload
        expect(session.progress.dig('context_manager', 'off_topic_count')).to eq(3)
      end
    end

    context 'AC validation' do
      it 'AC1: Recognizes question vs answer intent' do
        # Question
        result = execute_graphql(mutation,
          variables: { sessionId: session_id, content: "What do you mean by that?" },
          context: context
        )

        question_intent = result.dig('data', 'sendMessage', 'userMessage', 'metadata', 'intent')

        # Answer
        result = execute_graphql(mutation,
          variables: { sessionId: session_id, content: "42" },
          context: context
        )

        answer_intent = result.dig('data', 'sendMessage', 'userMessage', 'metadata', 'intent')

        expect(question_intent).not_to eq('answer')
        expect(answer_intent).to eq('answer')
      end

      it 'AC3: Off-topic responses are gently redirected to intake' do
        execute_graphql(mutation,
          variables: { sessionId: session_id, content: "How much does this cost?" },
          context: context
        )

        session.reload
        expect(session.progress.dig('context_manager', 'conversation_state')).to eq('off_topic')

        # Simulated return to intake
        execute_graphql(mutation,
          variables: { sessionId: session_id, content: "John" },
          context: context
        )

        session.reload
        expect(session.progress.dig('context_manager', 'conversation_state')).to eq('intake')
      end

      it 'AC6: Handles various help intent patterns' do
        help_patterns = [
          "I don't understand",
          "What does this mean",
          "Why are you asking",
          "I need help",
          "I'm confused"
        ]

        help_patterns.each do |pattern|
          # Reset session for each test
          test_session = create(:onboarding_session, status: :in_progress)
          test_session_id = "sess_#{test_session.id.gsub('-', '')}"
          test_context = { current_session_id: test_session.id }

          result = execute_graphql(mutation,
            variables: { sessionId: test_session_id, content: pattern },
            context: test_context
          )

          intent = result.dig('data', 'sendMessage', 'userMessage', 'metadata', 'intent')

          expect([:help_request, :clarification, :question]).to include(intent.to_sym),
                 "Expected #{pattern} to be classified as help-related, got #{intent}"
        end
      end

      it 'AC7: Conversation naturally returns to intake after addressing concerns' do
        # Help request
        execute_graphql(mutation,
          variables: { sessionId: session_id, content: "I don't understand" },
          context: context
        )

        expect(session.reload.progress.dig('context_manager', 'conversation_state')).to eq('help')

        # Answer (conversation recovery)
        execute_graphql(mutation,
          variables: { sessionId: session_id, content: "sarah@email.com" },
          context: context
        )

        expect(session.reload.progress.dig('context_manager', 'conversation_state')).to eq('intake')
      end
    end

    context 'metadata storage' do
      it 'stores all intent metadata in message' do
        variables = {
          sessionId: session_id,
          content: "I don't understand"
        }

        execute_graphql(mutation, variables: variables, context: context)

        message = Message.where(onboarding_session_id: session.id, role: :user).last
        expect(message.metadata['intent']).to be_present
        expect(message.metadata['intent_confidence']).to be_a(Float)
        expect(message.metadata['intent_pattern']).to be_present
        expect(message.metadata['intent_method']).to be_present
        expect(message.metadata['classified_at']).to be_present
      end
    end
  end
end
