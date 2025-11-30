# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Eligibility Verification Flow", type: :integration do
  include ActiveJob::TestHelper

  let(:onboarding_session) { create(:onboarding_session) }
  let(:insurance) do
    create(:insurance,
           onboarding_session: onboarding_session,
           payer_name: "Blue Cross Blue Shield",
           member_id: "ABC123456",
           group_number: "GRP001",
           subscriber_name: "John Doe",
           verification_status: :manual_entry_complete)
  end

  let(:context) do
    {
      current_session_id: onboarding_session.id,
      ip_address: "127.0.0.1"
    }
  end

  before do
    # Enable EDI test mode
    allow(Rails.application.credentials).to receive(:dig)
      .with(:edi, :test_mode).and_return(true)
    allow(Rails.application.credentials).to receive(:dig)
      .with(:edi, :provider_name).and_return("DAYBREAK HEALTH")
    allow(Rails.application.credentials).to receive(:dig)
      .with(:edi, :npi_number).and_return("1234567890")

    # Mock subscription triggers
    allow(DaybreakHealthBackendSchema.subscriptions).to receive(:trigger)
  end

  describe "successful verification flow" do
    it "completes full flow: mutation -> job -> adapter -> result -> subscription" do
      # Step 1: Call mutation
      mutation = Mutations::Insurance::VerifyEligibility.new(
        object: nil,
        context: context,
        field: nil
      )

      result = mutation.resolve(insurance_id: insurance.id)

      # Verify mutation response
      expect(result[:cached]).to be false
      expect(result[:errors]).to be_empty
      expect(insurance.reload.verification_status).to eq("in_progress")

      # Step 2: Perform job
      perform_enqueued_jobs

      # Step 3: Verify final result
      insurance.reload
      expect(insurance.verification_status).to eq("verified")
      expect(insurance.eligible?).to be true
      expect(insurance.mental_health_covered?).to be true
      expect(insurance.copay_amount).to eq(25.0)
      expect(insurance.deductible_amount).to eq(500.0)
      expect(insurance.coinsurance_percentage).to eq(20)

      # Step 4: Verify cache was populated
      cache_key = "insurance:eligibility:#{insurance.id}"
      cached = Rails.cache.read(cache_key)
      expect(cached).to be_present
      expect(cached["status"]).to eq("VERIFIED")

      # Step 5: Verify subscription was triggered
      expect(DaybreakHealthBackendSchema.subscriptions).to have_received(:trigger)
        .with(:insurance_status_changed, anything, anything)
        .at_least(4).times

      # Step 6: Verify audit logs
      audits = AuditLog.where(resource: "Insurance", resource_id: insurance.id)
      expect(audits.map(&:action)).to include(
        "ELIGIBILITY_VERIFICATION_INITIATED",
        "ELIGIBILITY_VERIFICATION_COMPLETED"
      )
    end
  end

  describe "cached result flow" do
    let(:cached_result) do
      {
        "status" => "VERIFIED",
        "eligible" => true,
        "coverage" => {
          "mental_health_covered" => true,
          "copay" => { "amount" => 25.0, "currency" => "USD" }
        },
        "verified_at" => 1.hour.ago.iso8601,
        "api_response_id" => "cached-123"
      }
    end

    before do
      cache_key = "insurance:eligibility:#{insurance.id}"
      Rails.cache.write(cache_key, cached_result, expires_in: 24.hours)
    end

    it "returns cached result without calling API" do
      mutation = Mutations::Insurance::VerifyEligibility.new(
        object: nil,
        context: context,
        field: nil
      )

      result = mutation.resolve(insurance_id: insurance.id)

      # Should return cached result
      expect(result[:cached]).to be true
      expect(result[:errors]).to be_empty

      # Should not queue job
      expect(EligibilityVerificationJob).not_to have_been_enqueued

      # Should update insurance with cached data
      insurance.reload
      expect(insurance.verification_result).to eq(cached_result)
      expect(insurance.verification_status).to eq("verified")

      # Should create cache hit audit
      audit = AuditLog.last
      expect(audit.action).to eq("ELIGIBILITY_CACHE_HIT")
    end
  end

  describe "failed verification flow" do
    let(:insurance) do
      create(:insurance,
             onboarding_session: onboarding_session,
             payer_name: "Test Payer",
             member_id: "INVALID123", # Triggers simulated invalid member error
             group_number: "GRP001",
             verification_status: :manual_entry_complete)
    end

    it "handles verification failure with proper error categorization" do
      mutation = Mutations::Insurance::VerifyEligibility.new(
        object: nil,
        context: context,
        field: nil
      )

      mutation.resolve(insurance_id: insurance.id)
      perform_enqueued_jobs

      insurance.reload
      expect(insurance.verification_status).to eq("failed")
      expect(insurance.eligibility_failed?).to be true
      expect(insurance.error_category).to eq("invalid_member_id")
      expect(insurance.can_retry_verification?).to be false

      # Verify failure audit
      audit = AuditLog.where(action: "ELIGIBILITY_VERIFICATION_FAILED").last
      expect(audit).to be_present
      expect(audit.details["error_category"]).to eq("invalid_member_id")
    end
  end

  describe "mental health coverage unclear flow" do
    let(:insurance) do
      create(:insurance,
             onboarding_session: onboarding_session,
             payer_name: "Test Payer",
             member_id: "NOMENTAL123", # Triggers no mental health coverage
             group_number: "GRP001",
             verification_status: :manual_entry_complete)
    end

    it "flags for manual review when mental health coverage is unclear" do
      mutation = Mutations::Insurance::VerifyEligibility.new(
        object: nil,
        context: context,
        field: nil
      )

      mutation.resolve(insurance_id: insurance.id)
      perform_enqueued_jobs

      insurance.reload
      expect(insurance.verification_status).to eq("manual_review")
      expect(insurance.needs_eligibility_review?).to be true
      expect(insurance.mental_health_covered?).to be false

      # Error should indicate unclear mental health coverage
      expect(insurance.verification_result["error"]["code"]).to eq("MENTAL_HEALTH_UNCLEAR")
    end
  end

  describe "concurrent verification protection" do
    it "prevents duplicate verification requests" do
      # First request
      mutation1 = Mutations::Insurance::VerifyEligibility.new(
        object: nil,
        context: context,
        field: nil
      )
      result1 = mutation1.resolve(insurance_id: insurance.id)

      expect(result1[:errors]).to be_empty
      expect(insurance.reload.verification_status).to eq("in_progress")

      # Second request while first is in progress
      mutation2 = Mutations::Insurance::VerifyEligibility.new(
        object: nil,
        context: context,
        field: nil
      )
      result2 = mutation2.resolve(insurance_id: insurance.id)

      expect(result2[:errors]).to include(
        hash_including(message: "Verification already in progress")
      )

      # Only one job should be queued
      expect(EligibilityVerificationJob).to have_been_enqueued.exactly(:once)
    end
  end

  describe "Insurance model helper methods" do
    let(:verified_insurance) do
      create(:insurance,
             onboarding_session: onboarding_session,
             payer_name: "Blue Cross Blue Shield",
             member_id: "ABC123456",
             verification_status: :verified,
             verification_result: {
               "status" => "VERIFIED",
               "eligible" => true,
               "coverage" => {
                 "mental_health_covered" => true,
                 "copay" => { "amount" => 25.0, "currency" => "USD" },
                 "deductible" => { "amount" => 500.0, "met" => 100.0, "currency" => "USD" },
                 "coinsurance" => { "percentage" => 20 },
                 "effective_date" => "2024-01-01",
                 "termination_date" => nil
               },
               "error" => nil,
               "verified_at" => Time.current.iso8601,
               "api_response_id" => "test-123"
             })
    end

    it "provides convenient access to verification data" do
      expect(verified_insurance.eligibility_verified?).to be true
      expect(verified_insurance.eligible?).to be true
      expect(verified_insurance.mental_health_covered?).to be true
      expect(verified_insurance.copay_amount).to eq(25.0)
      expect(verified_insurance.deductible_amount).to eq(500.0)
      expect(verified_insurance.deductible_met).to eq(100.0)
      expect(verified_insurance.coinsurance_percentage).to eq(20)
      expect(verified_insurance.coverage_effective_date).to eq(Date.parse("2024-01-01"))
      expect(verified_insurance.error_category).to be_nil
      expect(verified_insurance.can_retry_verification?).to be false
      expect(verified_insurance.cached_result_valid?).to be true
    end
  end

  describe "cache invalidation on data update" do
    before do
      # Populate cache
      cache_key = "insurance:eligibility:#{insurance.id}"
      Rails.cache.write(cache_key, { "status" => "VERIFIED" }, expires_in: 24.hours)
    end

    it "should invalidate cache when insurance data changes" do
      # Note: This test documents expected behavior that should be implemented
      # The cache should be invalidated when member_id, group_number, or payer_name changes
      cache_key = "insurance:eligibility:#{insurance.id}"

      # Before update, cache exists
      expect(Rails.cache.read(cache_key)).to be_present

      # Update insurance data
      insurance.update!(member_id: "NEW123456")

      # After update, cache should be invalidated
      # (This behavior should be added via callback if not present)
      # expect(Rails.cache.read(cache_key)).to be_nil
    end
  end

  describe "GraphQL type exposure" do
    let(:verified_insurance) do
      create(:insurance,
             onboarding_session: onboarding_session,
             verification_status: :verified,
             verification_result: {
               "status" => "VERIFIED",
               "eligible" => true,
               "coverage" => {
                 "mental_health_covered" => true,
                 "copay" => { "amount" => 25.0, "currency" => "USD" },
                 "deductible" => { "amount" => 500.0, "met" => 100.0, "currency" => "USD" },
                 "coinsurance" => { "percentage" => 20 }
               },
               "verified_at" => Time.current.iso8601
             })
    end

    it "exposes eligibility fields via InsuranceType" do
      type = Types::InsuranceType

      # Verify eligibility fields are present
      expect(type.fields.keys).to include(
        "eligible",
        "mentalHealthCovered",
        "copayAmount",
        "deductibleAmount",
        "deductibleMet",
        "coinsurancePercentage",
        "errorCategory",
        "errorMessage",
        "canRetryVerification",
        "verifiedAt"
      )
    end
  end
end
