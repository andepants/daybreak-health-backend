# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Conversation::SendMessage, type: :graphql do
  let(:session) { create(:onboarding_session, status: :in_progress) }
  let(:session_id) { "sess_#{session.id.gsub('-', '')}" }

  let(:mutation) do
    <<~GQL
      mutation SendMessage($sessionId: ID!, $content: String!) {
        sendMessage(sessionId: $sessionId, content: $content) {
          userMessage {
            id
            role
            content
            createdAt
          }
          assistantMessage {
            id
            role
            content
            createdAt
          }
          errors
        }
      }
    GQL
  end

  let(:variables) do
    {
      sessionId: session_id,
      content: "I need help with my child's anxiety"
    }
  end

  let(:context) { { current_session_id: session.id } }

  let(:mock_ai_client) { instance_double(Ai::Client) }
  let(:ai_response) do
    {
      content: "I understand your concern. Can you tell me more about what you've been noticing?",
      role: "assistant",
      provider: "anthropic"
    }
  end

  before do
    # Mock AI client to avoid actual API calls in tests
    allow(Ai::Client).to receive(:new).and_return(mock_ai_client)
    allow(mock_ai_client).to receive(:chat).and_return(ai_response)
  end

  describe "successful message sending" do
    it "stores user message with role USER (AC1)" do
      expect {
        execute_graphql(mutation, variables: variables, context: context)
      }.to change { Message.where(onboarding_session: session, role: :user).count }.by(1)

      user_message = Message.where(onboarding_session: session, role: :user).last
      expect(user_message.content).to eq("I need help with my child's anxiety")
      expect(user_message.created_at).to be_present
    end

    it "calls AI service with conversation context (AC2)" do
      expect(mock_ai_client).to receive(:chat) do |args|
        messages = args[:messages]

        # Should include system prompt
        expect(messages.first[:role]).to eq("system")

        # Should include user message
        expect(messages.last[:content]).to eq("I need help with my child's anxiety")

        ai_response
      end

      execute_graphql(mutation, variables: variables, context: context)
    end

    it "stores assistant response with role ASSISTANT (AC2)" do
      expect {
        execute_graphql(mutation, variables: variables, context: context)
      }.to change { Message.where(onboarding_session: session, role: :assistant).count }.by(1)

      assistant_message = Message.where(onboarding_session: session, role: :assistant).last
      expect(assistant_message.content).to include("I understand your concern")
      expect(assistant_message.created_at).to be_present
    end

    it "returns both messages in response" do
      result = execute_graphql(mutation, variables: variables, context: context)

      expect(result.dig("data", "sendMessage", "userMessage")).to be_present
      expect(result.dig("data", "sendMessage", "assistantMessage")).to be_present
      expect(result.dig("data", "sendMessage", "errors")).to be_empty

      user_msg = result.dig("data", "sendMessage", "userMessage")
      expect(user_msg["role"]).to eq("user")
      expect(user_msg["content"]).to eq("I need help with my child's anxiety")

      assistant_msg = result.dig("data", "sendMessage", "assistantMessage")
      expect(assistant_msg["role"]).to eq("assistant")
      expect(assistant_msg["content"]).to include("I understand your concern")
    end

    it "extends session expiration on activity" do
      # Set session to expire soon
      session.update!(expires_at: 10.minutes.from_now)
      original_expires_at = session.expires_at

      execute_graphql(mutation, variables: variables, context: context)
      session.reload

      # Session expiration should be extended to 1 hour from now
      expect(session.expires_at).to be > original_expires_at
      expect(session.expires_at).to be_within(1.second).of(1.hour.from_now)
    end

    it "creates audit logs for MESSAGE_SENT and AI_RESPONSE (AC8/Task 8)" do
      # Clear any existing audit logs to ensure clean test
      AuditLog.delete_all

      # Execute mutation - note: may create additional audit logs from other features (Story 3.2/3.3)
      # but we're only testing that MESSAGE_SENT and AI_RESPONSE are created
      execute_graphql(mutation, variables: variables, context: context)

      message_sent_log = AuditLog.find_by(action: "MESSAGE_SENT")
      expect(message_sent_log).to be_present
      expect(message_sent_log.details["role"]).to eq("user")
      expect(message_sent_log.details).not_to have_key("content") # PHI-safe

      ai_response_log = AuditLog.find_by(action: "AI_RESPONSE")
      expect(ai_response_log).to be_present
      expect(ai_response_log.details["role"]).to eq("assistant")
      expect(ai_response_log.details).not_to have_key("content") # PHI-safe
    end
  end

  describe "conversation context maintenance (AC4)" do
    before do
      # Create 5 previous messages
      5.times do |i|
        create(:message,
               onboarding_session: session,
               role: i.even? ? :user : :assistant,
               content: "Message #{i}")
      end
    end

    it "includes conversation history in AI context" do
      expect(mock_ai_client).to receive(:chat) do |args|
        messages = args[:messages]

        # Should include system prompt + previous messages + new message
        expect(messages.length).to be >= 6

        ai_response
      end

      execute_graphql(mutation, variables: variables, context: context)
    end
  end

  describe "error handling" do
    it "returns error for non-existent session" do
      variables[:sessionId] = "sess_00000000000000000000000000000000"

      result = execute_graphql(mutation, variables: variables, context: context)

      expect(result.dig("data", "sendMessage", "userMessage")).to be_nil
      expect(result.dig("data", "sendMessage", "errors")).to include("Session not found")
    end

    it "returns error for expired session" do
      session.update!(status: :expired)

      result = execute_graphql(mutation, variables: variables, context: context)

      expect(result.dig("data", "sendMessage", "errors")).to include("Session has expired")
    end

    it "returns error for submitted session" do
      # Follow valid transition path: in_progress -> insurance_pending -> assessment_complete -> submitted
      session.update!(status: :insurance_pending)
      session.update!(status: :assessment_complete)
      session.update!(status: :submitted)

      result = execute_graphql(mutation, variables: variables, context: context)

      expect(result.dig("data", "sendMessage", "errors")).to include("Session is already submitted")
    end

    it "returns error for abandoned session" do
      session.update!(status: :abandoned)

      result = execute_graphql(mutation, variables: variables, context: context)

      expect(result.dig("data", "sendMessage", "errors")).to include("Session has been abandoned")
    end

    it "handles AI rate limit gracefully" do
      allow(mock_ai_client).to receive(:chat).and_raise(Ai::Providers::BaseProvider::RateLimitError)

      result = execute_graphql(mutation, variables: variables, context: context)

      # Should still create user message but assistant message contains error explanation
      expect(result.dig("data", "sendMessage", "userMessage")).to be_present
      assistant_message = result.dig("data", "sendMessage", "assistantMessage")
      expect(assistant_message["content"]).to include("high volume")
    end

    it "handles AI API error gracefully" do
      allow(mock_ai_client).to receive(:chat).and_raise(Ai::Providers::BaseProvider::ApiError.new("API Error"))

      result = execute_graphql(mutation, variables: variables, context: context)

      # Should still create user message but assistant message contains error explanation
      expect(result.dig("data", "sendMessage", "userMessage")).to be_present
      assistant_message = result.dig("data", "sendMessage", "assistantMessage")
      expect(assistant_message["content"]).to include("having trouble")
    end
  end

  describe "message encryption (AC5)" do
    it "encrypts message content at database level" do
      execute_graphql(mutation, variables: variables, context: context)

      user_message = Message.where(onboarding_session: session, role: :user).last

      # Verify encrypted in database (same pattern as message_spec.rb)
      raw_content = ActiveRecord::Base.connection.execute(
        "SELECT content FROM messages WHERE id = '#{user_message.id}'"
      ).first["content"]

      expect(raw_content).not_to eq("I need help with my child's anxiety")
      expect(user_message.content).to eq("I need help with my child's anxiety")
    end
  end

  # Helper method to execute GraphQL
  def execute_graphql(query, variables: {}, context: {})
    DaybreakHealthBackendSchema.execute(query, variables: variables, context: context)
  end
end
