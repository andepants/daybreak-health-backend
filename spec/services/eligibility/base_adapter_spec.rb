# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligibility::BaseAdapter do
  subject(:adapter) { described_class.new }

  describe "#verify_eligibility" do
    let(:insurance) { build(:insurance) }

    it "raises NotImplementedError" do
      expect { adapter.verify_eligibility(insurance) }.to raise_error(
        NotImplementedError,
        "Subclass must implement verify_eligibility"
      )
    end
  end

  describe "constants" do
    it "defines TIMEOUT_SECONDS as 30" do
      expect(described_class::TIMEOUT_SECONDS).to eq(30)
    end

    it "defines all error categories" do
      categories = described_class::ERROR_CATEGORIES
      expect(categories).to include(
        invalid_member_id: "invalid_member_id",
        coverage_not_active: "coverage_not_active",
        service_not_covered: "service_not_covered",
        network_error: "network_error",
        timeout: "timeout",
        unknown: "unknown"
      )
    end
  end

  describe "protected helper methods" do
    # Create a test subclass to access protected methods
    let(:test_adapter) do
      Class.new(described_class) do
        public :build_verification_result,
               :determine_status,
               :timeout_error,
               :network_error,
               :build_coverage,
               :build_copay,
               :build_deductible,
               :build_coinsurance,
               :build_error
      end.new
    end

    describe "#build_verification_result" do
      it "builds complete result for successful verification" do
        result = test_adapter.build_verification_result(
          eligible: true,
          coverage: { mental_health_covered: true },
          error: nil
        )

        expect(result["status"]).to eq("VERIFIED")
        expect(result["eligible"]).to be true
        expect(result["coverage"]["mental_health_covered"]).to be true
        expect(result["error"]).to be_nil
        expect(result["verified_at"]).to be_present
        expect(result["api_response_id"]).to match(/^eligibility-/)
      end

      it "builds complete result for failed verification" do
        result = test_adapter.build_verification_result(
          eligible: false,
          coverage: {},
          error: { code: "TEST", category: "unknown", message: "Test error" }
        )

        expect(result["status"]).to eq("FAILED")
        expect(result["eligible"]).to be false
        expect(result["error"]["code"]).to eq("TEST")
      end
    end

    describe "#determine_status" do
      it "returns VERIFIED when eligible and no error" do
        expect(test_adapter.determine_status(true, nil)).to eq("VERIFIED")
      end

      it "returns FAILED when eligible is false and no error" do
        expect(test_adapter.determine_status(false, nil)).to eq("FAILED")
      end

      it "returns FAILED when error is present" do
        expect(test_adapter.determine_status(true, { code: "ERR" })).to eq("FAILED")
      end

      it "returns MANUAL_REVIEW when eligible is nil" do
        expect(test_adapter.determine_status(nil, nil)).to eq("MANUAL_REVIEW")
      end
    end

    describe "#timeout_error" do
      it "returns timeout error hash" do
        error = test_adapter.timeout_error

        expect(error[:code]).to eq("TIMEOUT")
        expect(error[:category]).to eq("timeout")
        expect(error[:message]).to include("30 seconds")
        expect(error[:retryable]).to be true
      end
    end

    describe "#network_error" do
      it "returns network error hash with exception message" do
        exception = StandardError.new("Connection refused")
        error = test_adapter.network_error(exception)

        expect(error[:code]).to eq("NETWORK_ERROR")
        expect(error[:category]).to eq("network_error")
        expect(error[:message]).to include("Connection refused")
        expect(error[:retryable]).to be true
      end
    end

    describe "#build_coverage" do
      it "builds coverage structure with all fields" do
        coverage = test_adapter.build_coverage(
          mental_health_covered: true,
          copay: { amount: 25.0 },
          deductible: { amount: 500.0 },
          coinsurance: { percentage: 20 },
          effective_date: "2024-01-01",
          termination_date: nil
        )

        expect(coverage[:mental_health_covered]).to be true
        expect(coverage[:copay][:amount]).to eq(25.0)
        expect(coverage[:deductible][:amount]).to eq(500.0)
        expect(coverage[:coinsurance][:percentage]).to eq(20)
        expect(coverage[:effective_date]).to eq("2024-01-01")
        expect(coverage.key?(:termination_date)).to be false # nil values compacted
      end

      it "compacts nil values" do
        coverage = test_adapter.build_coverage(
          mental_health_covered: true,
          copay: nil,
          deductible: nil
        )

        expect(coverage.keys).to eq([:mental_health_covered])
      end
    end

    describe "#build_copay" do
      it "builds copay structure with amount and currency" do
        copay = test_adapter.build_copay(amount: 25.99)

        expect(copay[:amount]).to eq(25.99)
        expect(copay[:currency]).to eq("USD")
      end

      it "rounds amount to 2 decimal places" do
        copay = test_adapter.build_copay(amount: 25.999)

        expect(copay[:amount]).to eq(26.0)
      end
    end

    describe "#build_deductible" do
      it "builds deductible structure with amount, met, and currency" do
        deductible = test_adapter.build_deductible(amount: 500, met: 150)

        expect(deductible[:amount]).to eq(500.0)
        expect(deductible[:met]).to eq(150.0)
        expect(deductible[:currency]).to eq("USD")
      end

      it "defaults met to 0" do
        deductible = test_adapter.build_deductible(amount: 500)

        expect(deductible[:met]).to eq(0.0)
      end
    end

    describe "#build_coinsurance" do
      it "builds coinsurance structure with percentage" do
        coinsurance = test_adapter.build_coinsurance(percentage: 20)

        expect(coinsurance[:percentage]).to eq(20)
      end

      it "converts percentage to integer" do
        coinsurance = test_adapter.build_coinsurance(percentage: 20.5)

        expect(coinsurance[:percentage]).to eq(20)
      end
    end

    describe "#build_error" do
      it "builds error hash with all fields" do
        error = test_adapter.build_error(
          category: :invalid_member_id,
          message: "Member not found",
          retryable: false,
          code: "AAA42"
        )

        expect(error[:code]).to eq("AAA42")
        expect(error[:category]).to eq("invalid_member_id")
        expect(error[:message]).to eq("Member not found")
        expect(error[:retryable]).to be false
      end

      it "generates code from category if not provided" do
        error = test_adapter.build_error(
          category: :network_error,
          message: "Network error"
        )

        expect(error[:code]).to eq("NETWORK_ERROR")
      end

      it "uses unknown category for unrecognized categories" do
        error = test_adapter.build_error(
          category: :invalid_category,
          message: "Some error"
        )

        expect(error[:category]).to eq("unknown")
      end
    end
  end
end
