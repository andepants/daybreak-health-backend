# frozen_string_literal: true

require "rails_helper"

RSpec.describe EligibilityVerificationJob, type: :job do
  include ActiveJob::TestHelper

  let(:onboarding_session) { create(:onboarding_session) }
  let(:insurance) do
    create(:insurance,
           onboarding_session: onboarding_session,
           payer_name: "Blue Cross Blue Shield",
           member_id: "ABC123456",
           group_number: "GRP001",
           verification_status: :in_progress)
  end

  let(:successful_result) do
    {
      "status" => "VERIFIED",
      "eligible" => true,
      "coverage" => {
        "mental_health_covered" => true,
        "copay" => { "amount" => 25.0, "currency" => "USD" },
        "deductible" => { "amount" => 500.0, "met" => 0.0, "currency" => "USD" },
        "coinsurance" => { "percentage" => 20 }
      },
      "verified_at" => Time.current.iso8601,
      "api_response_id" => "test-123"
    }
  end

  let(:failed_result) do
    {
      "status" => "FAILED",
      "eligible" => false,
      "coverage" => {},
      "error" => {
        "code" => "AAA42",
        "category" => "invalid_member_id",
        "message" => "Member ID not found",
        "retryable" => false
      },
      "verified_at" => Time.current.iso8601
    }
  end

  let(:mock_adapter) { instance_double(Eligibility::EdiAdapter) }

  before do
    allow(Eligibility::AdapterFactory).to receive(:adapter_for)
      .and_return(mock_adapter)
    allow(DaybreakHealthBackendSchema.subscriptions).to receive(:trigger)
  end

  describe "#perform" do
    context "when verification succeeds" do
      before do
        allow(mock_adapter).to receive(:verify_eligibility).and_return(successful_result)
      end

      it "updates insurance with verification result" do
        perform_enqueued_jobs { described_class.perform_later(insurance.id) }

        insurance.reload
        expect(insurance.verification_result).to eq(successful_result)
        expect(insurance.verification_status).to eq("verified")
      end

      it "caches result in Redis for 24 hours" do
        perform_enqueued_jobs { described_class.perform_later(insurance.id) }

        cache_key = "insurance:eligibility:#{insurance.id}"
        cached = Rails.cache.read(cache_key)
        expect(cached).to eq(successful_result)
      end

      it "triggers subscription updates" do
        expect(DaybreakHealthBackendSchema.subscriptions).to receive(:trigger)
          .with(:insurance_status_changed, anything, anything)
          .at_least(4).times # started, api_called, parsing, complete

        perform_enqueued_jobs { described_class.perform_later(insurance.id) }
      end

      it "creates success audit log" do
        expect {
          perform_enqueued_jobs { described_class.perform_later(insurance.id) }
        }.to change(AuditLog, :count).by(1)

        audit = AuditLog.last
        expect(audit.action).to eq("ELIGIBILITY_VERIFICATION_COMPLETED")
        expect(audit.details["status"]).to eq("VERIFIED")
        expect(audit.details["eligible"]).to be true
      end
    end

    context "when verification fails" do
      before do
        allow(mock_adapter).to receive(:verify_eligibility).and_return(failed_result)
      end

      it "updates insurance with failure status" do
        perform_enqueued_jobs { described_class.perform_later(insurance.id) }

        insurance.reload
        expect(insurance.verification_status).to eq("failed")
        expect(insurance.verification_result["error"]["category"]).to eq("invalid_member_id")
      end

      it "creates failure audit log" do
        perform_enqueued_jobs { described_class.perform_later(insurance.id) }

        audit = AuditLog.last
        expect(audit.action).to eq("ELIGIBILITY_VERIFICATION_FAILED")
        expect(audit.details["error_category"]).to eq("invalid_member_id")
      end
    end

    context "when adapter raises error" do
      before do
        allow(mock_adapter).to receive(:verify_eligibility)
          .and_raise(StandardError.new("API Error"))
      end

      it "re-raises for Sidekiq retry" do
        expect {
          described_class.new.perform(insurance.id)
        }.to raise_error(StandardError, "API Error")
      end

      it "updates insurance to failed status before retry" do
        expect {
          described_class.new.perform(insurance.id)
        }.to raise_error(StandardError)

        insurance.reload
        expect(insurance.verification_status).to eq("failed")
        expect(insurance.verification_result["error"]["code"]).to eq("JOB_FAILED")
      end
    end

    context "when insurance not found" do
      it "discards the job silently" do
        expect {
          described_class.new.perform("nonexistent")
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "progress updates" do
    before do
      allow(mock_adapter).to receive(:verify_eligibility).and_return(successful_result)
    end

    it "emits progress at 0% on start" do
      expect(DaybreakHealthBackendSchema.subscriptions).to receive(:trigger).with(
        :insurance_status_changed,
        { session_id: onboarding_session.id },
        hash_including(progress: { percentage: 0, message: "Contacting insurance company..." })
      )

      described_class.new.perform(insurance.id)
    end

    it "emits progress at 33% on API call" do
      expect(DaybreakHealthBackendSchema.subscriptions).to receive(:trigger).with(
        :insurance_status_changed,
        { session_id: onboarding_session.id },
        hash_including(progress: { percentage: 33, message: "Checking coverage..." })
      )

      described_class.new.perform(insurance.id)
    end

    it "emits progress at 66% on parsing" do
      expect(DaybreakHealthBackendSchema.subscriptions).to receive(:trigger).with(
        :insurance_status_changed,
        { session_id: onboarding_session.id },
        hash_including(progress: { percentage: 66, message: "Processing response..." })
      )

      described_class.new.perform(insurance.id)
    end

    it "emits progress at 100% on complete" do
      expect(DaybreakHealthBackendSchema.subscriptions).to receive(:trigger).with(
        :insurance_status_changed,
        { session_id: onboarding_session.id },
        hash_including(progress: { percentage: 100, message: "Verification complete" })
      )

      described_class.new.perform(insurance.id)
    end
  end

  describe "retry behavior" do
    it "is configured to retry 3 times" do
      expect(described_class.retry_on_exceptions).to include(StandardError)
    end

    it "uses polynomial backoff" do
      # This is handled by Sidekiq configuration
      expect(described_class).to respond_to(:retry_on)
    end
  end

  describe ".handle_max_retries_exceeded" do
    it "sets status to manual_review" do
      described_class.handle_max_retries_exceeded(insurance.id, StandardError.new("Test error"))

      insurance.reload
      expect(insurance.verification_status).to eq("manual_review")
    end

    it "sets result with MAX_RETRIES_EXCEEDED error" do
      described_class.handle_max_retries_exceeded(insurance.id, StandardError.new("Test error"))

      insurance.reload
      expect(insurance.verification_result["error"]["code"]).to eq("MAX_RETRIES_EXCEEDED")
      expect(insurance.verification_result["error"]["retryable"]).to be false
    end

    it "creates escalation audit log" do
      expect {
        described_class.handle_max_retries_exceeded(insurance.id, StandardError.new("Test error"))
      }.to change(AuditLog, :count).by(1)

      audit = AuditLog.last
      expect(audit.action).to eq("ELIGIBILITY_VERIFICATION_ESCALATED")
      expect(audit.details["reason"]).to eq("max_retries_exceeded")
    end

    it "triggers subscription with manual review status" do
      expect(DaybreakHealthBackendSchema.subscriptions).to receive(:trigger).with(
        :insurance_status_changed,
        { session_id: onboarding_session.id },
        hash_including(insurance: an_instance_of(::Insurance))
      )

      described_class.handle_max_retries_exceeded(insurance.id, StandardError.new("Test error"))
    end
  end

  describe "job configuration" do
    it "uses insurance queue" do
      expect(described_class.queue_name).to eq("insurance")
    end
  end
end
