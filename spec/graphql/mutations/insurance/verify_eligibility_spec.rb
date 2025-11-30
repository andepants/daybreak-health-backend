# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe Mutations::Insurance::VerifyEligibility, type: :graphql do
  let(:onboarding_session) { create(:onboarding_session) }
  let(:insurance) do
    create(:insurance,
           onboarding_session: onboarding_session,
           payer_name: "Blue Cross Blue Shield",
           member_id: "ABC123456",
           group_number: "GRP001",
           verification_status: :pending)
  end
  let(:context) do
    {
      current_session_id: onboarding_session.id,
      ip_address: "127.0.0.1"
    }
  end

  # Helper method to call mutation resolve directly (bypassing GraphQL initialization)
  def resolve_mutation(**args)
    mutation = described_class.allocate
    mutation.instance_variable_set(:@context, context)
    mutation.resolve(**args)
  end

  describe "#resolve" do
    context "when insurance exists and is authorized" do
      before do
        allow(EligibilityVerificationJob).to receive(:perform_later)
      end

      it "queues verification job" do
        expect(EligibilityVerificationJob).to receive(:perform_later).with(insurance.id)

        resolve_mutation(insurance_id: insurance.id)
      end

      it "updates insurance status to in_progress" do
        resolve_mutation(insurance_id: insurance.id)

        expect(insurance.reload.verification_status).to eq("in_progress")
      end

      it "returns insurance and cached: false" do
        result = resolve_mutation(insurance_id: insurance.id)

        expect(result[:insurance]).to be_present
        expect(result[:cached]).to be false
        expect(result[:errors]).to be_empty
      end

      it "creates audit log" do
        insurance # ensure insurance exists

        resolve_mutation(insurance_id: insurance.id)

        audit = AuditLog.where(action: "ELIGIBILITY_VERIFICATION_INITIATED").last
        expect(audit).to be_present
        expect(audit.resource).to eq("Insurance")
        expect(audit.resource_id).to eq(insurance.id)
      end
    end

    context "when cached result exists" do
      let(:cached_result) do
        {
          "status" => "VERIFIED",
          "eligible" => true,
          "coverage" => { "mental_health_covered" => true },
          "verified_at" => 1.hour.ago.iso8601
        }
      end

      around do |example|
        # Temporarily enable memory caching for these tests
        original_cache = Rails.cache
        Rails.cache = ActiveSupport::Cache::MemoryStore.new
        insurance # create insurance first
        cache_key = "insurance:eligibility:#{insurance.id}"
        Rails.cache.write(cache_key, cached_result, expires_in: 24.hours)

        example.run

        Rails.cache = original_cache
      end

      it "returns cached result without queuing job" do
        expect(EligibilityVerificationJob).not_to receive(:perform_later)

        result = resolve_mutation(insurance_id: insurance.id)

        expect(result[:cached]).to be true
        expect(result[:errors]).to be_empty
      end

      it "updates insurance with cached result" do
        resolve_mutation(insurance_id: insurance.id)

        expect(insurance.reload.verification_result).to eq(cached_result)
        expect(insurance.verification_status).to eq("verified")
      end

      it "creates cache hit audit log" do
        resolve_mutation(insurance_id: insurance.id)

        audit = AuditLog.where(action: "ELIGIBILITY_CACHE_HIT").last
        expect(audit).to be_present
      end
    end

    context "when insurance not found" do
      it "returns error" do
        result = resolve_mutation(insurance_id: "nonexistent")

        expect(result[:insurance]).to be_nil
        expect(result[:errors]).to include(
          hash_including(field: "insurance_id", message: "Insurance record not found")
        )
      end
    end

    context "when session is unauthorized" do
      let(:context) do
        {
          current_session_id: SecureRandom.uuid, # Different session
          ip_address: "127.0.0.1"
        }
      end

      it "returns unauthorized error" do
        result = resolve_mutation(insurance_id: insurance.id)

        expect(result[:insurance]).to be_nil
        expect(result[:errors]).to include(
          hash_including(field: "insurance_id", message: "Unauthorized")
        )
      end
    end

    context "when session is expired" do
      before do
        onboarding_session.update!(
          expires_at: 1.day.ago,
          status: :expired
        )
      end

      it "returns session expired error" do
        result = resolve_mutation(insurance_id: insurance.id)

        expect(result[:insurance]).to be_nil
        expect(result[:errors]).to include(
          hash_including(field: "session", message: "Session has expired")
        )
      end
    end

    context "when insurance is missing required data" do
      let(:insurance) do
        create(:insurance,
               onboarding_session: onboarding_session,
               payer_name: nil,
               member_id: nil,
               verification_status: :pending)
      end

      it "returns validation error" do
        result = resolve_mutation(insurance_id: insurance.id)

        expect(result[:insurance]).to be_nil
        expect(result[:errors]).to include(
          hash_including(message: "Insurance must have member ID and payer name")
        )
      end
    end

    context "when verification is already in progress" do
      before do
        insurance.update!(verification_status: :in_progress)
      end

      it "returns already in progress error" do
        result = resolve_mutation(insurance_id: insurance.id)

        expect(result[:errors]).to include(
          hash_including(message: "Verification already in progress")
        )
      end

      it "does not queue another job" do
        expect(EligibilityVerificationJob).not_to receive(:perform_later)

        resolve_mutation(insurance_id: insurance.id)
      end
    end
  end

  describe "GraphQL schema integration" do
    let(:query) do
      <<~GQL
        mutation VerifyEligibility($insuranceId: ID!) {
          verifyEligibility(insuranceId: $insuranceId) {
            insurance {
              id
              verificationStatus
            }
            cached
            errors {
              field
              message
            }
          }
        }
      GQL
    end

    it "is registered in MutationType" do
      field = Types::MutationType.fields["verifyEligibility"]
      expect(field).to be_present
      expect(field.mutation).to eq(described_class)
    end
  end
end
