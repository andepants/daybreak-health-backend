# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::InsuranceStatusChanged, type: :graphql do
  let(:onboarding_session) { create(:onboarding_session) }
  let(:insurance) do
    create(:insurance,
           onboarding_session: onboarding_session,
           payer_name: "Blue Cross Blue Shield",
           member_id: "ABC123456",
           verification_status: :pending)
  end

  let(:subscription) { described_class.new(object: nil, context: {}, field: nil) }

  describe "#subscribe" do
    context "when session and insurance exist" do
      it "returns insurance record" do
        result = subscription.subscribe(session_id: onboarding_session.id)

        expect(result[:insurance]).to eq(insurance)
        expect(result[:progress]).to be_nil
      end
    end

    context "when session not found" do
      it "raises execution error" do
        expect {
          subscription.subscribe(session_id: "nonexistent")
        }.to raise_error(GraphQL::ExecutionError, "Session not found")
      end
    end

    context "when session has no insurance" do
      let(:session_without_insurance) { create(:onboarding_session) }

      it "raises execution error" do
        expect {
          subscription.subscribe(session_id: session_without_insurance.id)
        }.to raise_error(GraphQL::ExecutionError, "No insurance record for session")
      end
    end
  end

  describe "#update" do
    context "when object is hash with insurance and progress" do
      let(:progress_data) do
        {
          percentage: 33,
          message: "Checking coverage..."
        }
      end

      let(:update_object) do
        {
          insurance: insurance,
          progress: progress_data
        }
      end

      it "returns insurance and progress" do
        subscription.instance_variable_set(:@object, update_object)
        result = subscription.update(session_id: onboarding_session.id)

        expect(result[:insurance]).to eq(insurance)
        expect(result[:progress]).to eq(progress_data)
      end
    end

    context "when object is hash with insurance only" do
      let(:update_object) do
        {
          insurance: insurance
        }
      end

      it "returns insurance with nil progress" do
        subscription.instance_variable_set(:@object, update_object)
        result = subscription.update(session_id: onboarding_session.id)

        expect(result[:insurance]).to eq(insurance)
        expect(result[:progress]).to be_nil
      end
    end

    context "when object is direct insurance record" do
      it "returns insurance with nil progress" do
        subscription.instance_variable_set(:@object, insurance)
        result = subscription.update(session_id: onboarding_session.id)

        expect(result[:insurance]).to eq(insurance)
        expect(result[:progress]).to be_nil
      end
    end
  end

  describe "schema integration" do
    it "is registered in SubscriptionType" do
      field = Types::SubscriptionType.fields["insuranceStatusChanged"]
      expect(field).to be_present
    end

    it "accepts session_id argument" do
      field = Types::SubscriptionType.fields["insuranceStatusChanged"]
      session_id_arg = field.arguments["sessionId"]

      expect(session_id_arg).to be_present
      expect(session_id_arg.type.to_type_signature).to eq("ID!")
    end

    it "returns InsuranceType for insurance field" do
      field = Types::SubscriptionType.fields["insuranceStatusChanged"]
      insurance_field = described_class.fields["insurance"]

      expect(insurance_field.type.to_type_signature).to eq("InsuranceType!")
    end

    it "returns VerificationProgressType for progress field" do
      progress_field = described_class.fields["progress"]

      expect(progress_field.type.to_type_signature).to eq("VerificationProgressType")
    end
  end

  describe "triggering subscription" do
    let(:successful_result) do
      {
        "status" => "VERIFIED",
        "eligible" => true,
        "coverage" => { "mental_health_covered" => true }
      }
    end

    context "from EligibilityVerificationJob" do
      it "triggers with progress updates during verification" do
        expect(DaybreakHealthBackendSchema.subscriptions).to receive(:trigger).with(
          :insurance_status_changed,
          { session_id: onboarding_session.id },
          hash_including(
            insurance: insurance,
            progress: { percentage: 0, message: "Contacting insurance company..." }
          )
        )

        DaybreakHealthBackendSchema.subscriptions.trigger(
          :insurance_status_changed,
          { session_id: onboarding_session.id },
          {
            insurance: insurance,
            progress: { percentage: 0, message: "Contacting insurance company..." }
          }
        )
      end

      it "triggers on final result" do
        insurance.update!(
          verification_result: successful_result,
          verification_status: :verified
        )

        expect(DaybreakHealthBackendSchema.subscriptions).to receive(:trigger).with(
          :insurance_status_changed,
          { session_id: onboarding_session.id },
          { insurance: insurance }
        )

        DaybreakHealthBackendSchema.subscriptions.trigger(
          :insurance_status_changed,
          { session_id: onboarding_session.id },
          { insurance: insurance }
        )
      end
    end
  end
end
