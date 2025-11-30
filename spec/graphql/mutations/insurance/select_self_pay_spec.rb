# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Insurance::SelectSelfPay, type: :graphql do
  let(:session) { create(:onboarding_session, :with_insurance) }
  let(:insurance) { session.insurance }
  let(:session_id) { "sess_#{session.id.gsub('-', '')}" }

  let(:mutation) do
    <<~GQL
      mutation SelectSelfPay($sessionId: ID!) {
        selectSelfPay(input: { sessionId: $sessionId }) {
          session {
            id
            insurance {
              verificationStatus
              verifiedAt
            }
          }
          success
        }
      }
    GQL
  end

  describe "successful self-pay selection" do
    it "sets insurance verification status to self_pay" do
      result = execute_graphql(
        mutation,
        variables: { sessionId: session_id },
        context: { current_session: session }
      )

      expect(result.dig("errors")).to be_nil
      expect(result.dig("data", "selectSelfPay", "success")).to eq(true)
      expect(result.dig("data", "selectSelfPay", "session", "insurance", "verificationStatus")).to eq("self_pay")
      expect(result.dig("data", "selectSelfPay", "session", "insurance", "verifiedAt")).not_to be_nil

      # Verify database state
      insurance.reload
      expect(insurance.verification_status).to eq("self_pay")
      expect(insurance.verified_at).not_to be_nil
    end

    it "works with UUID format session IDs" do
      result = execute_graphql(
        mutation,
        variables: { sessionId: session.id },
        context: { current_session: session }
      )

      expect(result.dig("errors")).to be_nil
      expect(result.dig("data", "selectSelfPay", "success")).to eq(true)
    end

    it "creates insurance record if it doesn't exist" do
      session_without_insurance = create(:onboarding_session)

      expect(session_without_insurance.insurance).to be_nil

      result = execute_graphql(
        mutation,
        variables: { sessionId: session_without_insurance.id },
        context: { current_session: session_without_insurance }
      )

      expect(result.dig("errors")).to be_nil
      expect(result.dig("data", "selectSelfPay", "success")).to eq(true)

      # Verify insurance was created
      session_without_insurance.reload
      expect(session_without_insurance.insurance).not_to be_nil
      expect(session_without_insurance.insurance.verification_status).to eq("self_pay")
    end
  end

  describe "authorization errors" do
    it "returns error when not authenticated" do
      result = execute_graphql(
        mutation,
        variables: { sessionId: session_id },
        context: {}
      )

      expect(result.dig("errors")).not_to be_nil
      expect(result.dig("errors", 0, "extensions", "code")).to eq("UNAUTHENTICATED")
    end

    it "returns error when accessing another user's session" do
      other_session = create(:onboarding_session)

      result = execute_graphql(
        mutation,
        variables: { sessionId: session_id },
        context: { current_session: other_session }
      )

      expect(result.dig("errors")).not_to be_nil
      expect(result.dig("errors", 0, "extensions", "code")).to eq("UNAUTHENTICATED")
    end
  end

  describe "error handling" do
    it "returns error when session not found" do
      result = execute_graphql(
        mutation,
        variables: { sessionId: "00000000-0000-0000-0000-000000000000" },
        context: { current_session: session }
      )

      expect(result.dig("errors")).not_to be_nil
      expect(result.dig("errors", 0, "extensions", "code")).to eq("NOT_FOUND")
    end
  end
end
