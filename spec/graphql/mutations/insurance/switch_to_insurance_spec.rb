# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Insurance::SwitchToInsurance, type: :graphql do
  let(:session) { create(:onboarding_session, :with_insurance) }
  let(:insurance) { session.insurance }
  let(:session_id) { "sess_#{session.id.gsub('-', '')}" }

  let(:mutation) do
    <<~GQL
      mutation SwitchToInsurance($sessionId: ID!) {
        switchToInsurance(input: { sessionId: $sessionId }) {
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

  before do
    # Set insurance to self_pay status first
    insurance.verification_status = :self_pay
    insurance.verification_result = { "verified_at" => Time.current.iso8601 }
    insurance.save!
  end

  describe "successful switch back to insurance" do
    context "when insurance info exists" do
      before do
        insurance.update!(
          payer_name: "Blue Cross Blue Shield",
          member_id: "TEST123456"
        )
      end

      it "sets verification status to pending" do
        result = execute_graphql(
          mutation,
          variables: { sessionId: session_id },
          context: { current_session: session }
        )

        expect(result.dig("errors")).to be_nil
        expect(result.dig("data", "switchToInsurance", "success")).to eq(true)
        expect(result.dig("data", "switchToInsurance", "session", "insurance", "verificationStatus")).to eq("pending")
        expect(result.dig("data", "switchToInsurance", "session", "insurance", "verifiedAt")).to be_nil

        # Verify database state
        insurance.reload
        expect(insurance.verification_status).to eq("pending")
        expect(insurance.verified_at).to be_nil
      end
    end

    context "when insurance info does not exist" do
      before do
        insurance.update!(
          payer_name: nil,
          member_id: nil
        )
      end

      it "sets verification status to failed" do
        result = execute_graphql(
          mutation,
          variables: { sessionId: session_id },
          context: { current_session: session }
        )

        expect(result.dig("errors")).to be_nil
        expect(result.dig("data", "switchToInsurance", "success")).to eq(true)
        expect(result.dig("data", "switchToInsurance", "session", "insurance", "verificationStatus")).to eq("failed")

        # Verify database state
        insurance.reload
        expect(insurance.verification_status).to eq("failed")
      end
    end

    it "works with UUID format session IDs" do
      insurance.update!(payer_name: "Blue Cross Blue Shield")

      result = execute_graphql(
        mutation,
        variables: { sessionId: session.id },
        context: { current_session: session }
      )

      expect(result.dig("errors")).to be_nil
      expect(result.dig("data", "switchToInsurance", "success")).to eq(true)
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

    it "returns error when insurance record does not exist" do
      session_without_insurance = create(:onboarding_session)

      result = execute_graphql(
        mutation,
        variables: { sessionId: session_without_insurance.id },
        context: { current_session: session_without_insurance }
      )

      expect(result.dig("errors")).not_to be_nil
      expect(result.dig("errors", 0, "extensions", "code")).to eq("NOT_FOUND")
    end
  end
end
