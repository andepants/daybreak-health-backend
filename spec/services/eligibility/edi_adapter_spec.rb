# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligibility::EdiAdapter do
  subject(:adapter) { described_class.new }

  let(:onboarding_session) { create(:onboarding_session) }
  let(:insurance) do
    create(:insurance,
           onboarding_session: onboarding_session,
           payer_name: "Blue Cross Blue Shield",
           member_id: "ABC123456",
           group_number: "GRP001",
           subscriber_name: "John Doe")
  end

  describe "#verify_eligibility" do
    context "when verification is successful" do
      # Rails.env.test? is true in specs, so EDI adapter uses simulation mode automatically

      it "returns successful verification result" do
        result = adapter.verify_eligibility(insurance)

        expect(result["status"]).to eq("VERIFIED")
        expect(result["eligible"]).to be true
        expect(result["coverage"]["mental_health_covered"]).to be true
        expect(result["verified_at"]).to be_present
        expect(result["api_response_id"]).to be_present
      end

      it "includes copay information" do
        result = adapter.verify_eligibility(insurance)

        expect(result["coverage"]["copay"]).to be_present
        expect(result["coverage"]["copay"]["amount"]).to eq(25.0)
        expect(result["coverage"]["copay"]["currency"]).to eq("USD")
      end

      it "includes deductible information" do
        result = adapter.verify_eligibility(insurance)

        expect(result["coverage"]["deductible"]).to be_present
        expect(result["coverage"]["deductible"]["amount"]).to eq(500.0)
      end

      it "includes coinsurance information" do
        result = adapter.verify_eligibility(insurance)

        expect(result["coverage"]["coinsurance"]).to be_present
        expect(result["coverage"]["coinsurance"]["percentage"]).to eq(20)
      end
    end

    context "when member ID is invalid" do
      let(:insurance) do
        create(:insurance,
               onboarding_session: onboarding_session,
               payer_name: "Blue Cross Blue Shield",
               member_id: "INVALID123",
               group_number: "GRP001")
      end

      # Rails.env.test? is true in specs, so EDI adapter uses simulation mode automatically

      it "returns failed result with invalid_member_id category" do
        result = adapter.verify_eligibility(insurance)

        expect(result["status"]).to eq("FAILED")
        expect(result["eligible"]).to be false
        expect(result["error"]["category"]).to eq("invalid_member_id")
        expect(result["error"]["retryable"]).to be false
      end
    end

    context "when coverage is inactive" do
      let(:insurance) do
        create(:insurance,
               onboarding_session: onboarding_session,
               payer_name: "Blue Cross Blue Shield",
               member_id: "INACTIVE123",
               group_number: "GRP001")
      end

      it "returns failed result with coverage_not_active category" do
        result = adapter.verify_eligibility(insurance)

        expect(result["status"]).to eq("FAILED")
        expect(result["error"]["category"]).to eq("coverage_not_active")
      end
    end

    context "when mental health is not covered" do
      let(:insurance) do
        create(:insurance,
               onboarding_session: onboarding_session,
               payer_name: "Blue Cross Blue Shield",
               member_id: "NOMENTAL123",
               group_number: "GRP001")
      end

      it "returns manual review status when mental health coverage is unclear" do
        result = adapter.verify_eligibility(insurance)

        expect(result["status"]).to eq("MANUAL_REVIEW")
        expect(result["eligible"]).to be_nil
        expect(result["coverage"]["mental_health_covered"]).to be false
        expect(result["error"]["code"]).to eq("MENTAL_HEALTH_UNCLEAR")
      end
    end

    context "when timeout occurs" do
      before do
        allow(adapter).to receive(:send_edi_transaction).and_raise(Timeout::Error)
      end

      it "returns failed result with timeout category" do
        result = adapter.verify_eligibility(insurance)

        expect(result["status"]).to eq("MANUAL_REVIEW")
        expect(result["eligible"]).to be_nil
        expect(result["error"]["category"]).to eq("timeout")
        expect(result["error"]["retryable"]).to be true
      end
    end

    context "when network error occurs" do
      before do
        allow(adapter).to receive(:send_edi_transaction)
          .and_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "returns failed result with network_error category" do
        result = adapter.verify_eligibility(insurance)

        expect(result["status"]).to eq("MANUAL_REVIEW")
        expect(result["error"]["category"]).to eq("network_error")
        expect(result["error"]["retryable"]).to be true
      end
    end

    context "when unexpected error occurs" do
      before do
        allow(adapter).to receive(:send_edi_transaction)
          .and_raise(StandardError.new("Unexpected error"))
      end

      it "returns failed result with unknown category" do
        result = adapter.verify_eligibility(insurance)

        expect(result["status"]).to eq("FAILED")
        expect(result["error"]["category"]).to eq("unknown")
        expect(result["error"]["retryable"]).to be true
      end
    end
  end

  describe "EDI 270 request building" do
    let(:adapter_with_public_methods) do
      Class.new(described_class) do
        public :build_edi_270
      end.new
    end

    it "builds request with required segments" do
      request = adapter_with_public_methods.build_edi_270(insurance)

      expect(request[:transaction_set]).to eq("270")
      expect(request[:control_number]).to be_present
      expect(request[:trace_id]).to match(/^DYBK/)
      expect(request[:segments]).to be_an(Array)
    end

    it "includes payer information" do
      request = adapter_with_public_methods.build_edi_270(insurance)
      nm1_segments = request[:segments].select { |s| s[:segment] == "NM1" }

      payer_segment = nm1_segments.find { |s| s[:elements].first == "PR" }
      expect(payer_segment).to be_present
      expect(payer_segment[:elements]).to include(/BLUE CROSS/i)
    end

    it "includes member ID reference" do
      request = adapter_with_public_methods.build_edi_270(insurance)
      ref_segments = request[:segments].select { |s| s[:segment] == "REF" }

      member_ref = ref_segments.find { |s| s[:elements].first == "0F" }
      expect(member_ref).to be_present
      expect(member_ref[:elements][1]).to eq("ABC123456")
    end

    it "includes group number reference when present" do
      request = adapter_with_public_methods.build_edi_270(insurance)
      ref_segments = request[:segments].select { |s| s[:segment] == "REF" }

      group_ref = ref_segments.find { |s| s[:elements].first == "1L" }
      expect(group_ref).to be_present
      expect(group_ref[:elements][1]).to eq("GRP001")
    end

    it "includes mental health service type inquiry" do
      request = adapter_with_public_methods.build_edi_270(insurance)
      eq_segments = request[:segments].select { |s| s[:segment] == "EQ" }

      mental_health_eq = eq_segments.find { |s| s[:elements].first == "MH" }
      expect(mental_health_eq).to be_present
    end
  end

  describe "EDI 271 response parsing" do
    let(:adapter_with_public_methods) do
      Class.new(described_class) do
        public :parse_edi_271
      end.new
    end

    context "with successful response" do
      let(:response) do
        {
          segments: [
            { segment: "EB", elements: ["1", "IND", "", "MH", "", "", "25.00"] },
            { segment: "EB", elements: ["C", "IND", "", "30", "", "", "500.00"] },
            { segment: "EB", elements: ["A", "IND", "", "30", "", "", "", "0.20"] },
            { segment: "DTP", elements: ["348", "D8", "20240101"] }
          ]
        }
      end

      it "parses eligibility status" do
        result = adapter_with_public_methods.parse_edi_271(response)

        expect(result["status"]).to eq("VERIFIED")
        expect(result["eligible"]).to be true
        expect(result["coverage"]["mental_health_covered"]).to be true
      end
    end

    context "with error response" do
      let(:response) do
        {
          segments: [
            { segment: "AAA", elements: ["Y", "42", "", "C"] }
          ]
        }
      end

      it "parses error code and returns failure" do
        result = adapter_with_public_methods.parse_edi_271(response)

        expect(result["status"]).to eq("FAILED")
        expect(result["eligible"]).to be false
        expect(result["error"]["code"]).to eq("AAA42")
        expect(result["error"]["category"]).to eq("invalid_member_id")
      end
    end

    context "with empty EB segments" do
      let(:response) do
        {
          segments: []
        }
      end

      it "returns manual review status" do
        result = adapter_with_public_methods.parse_edi_271(response)

        expect(result["status"]).to eq("MANUAL_REVIEW")
        expect(result["eligible"]).to be_nil
        expect(result["error"]["message"]).to include("No eligibility information")
      end
    end
  end

  describe "error code mappings" do
    it "maps AAA42 to invalid_member_id" do
      expect(described_class::ERROR_MAPPINGS["42"][:category]).to eq(:invalid_member_id)
    end

    it "maps AAA56 to coverage_not_active" do
      expect(described_class::ERROR_MAPPINGS["56"][:category]).to eq(:coverage_not_active)
    end

    it "maps AAA58 to service_not_covered" do
      expect(described_class::ERROR_MAPPINGS["58"][:category]).to eq(:service_not_covered)
    end

    it "maps AAA72 to network_error with retryable true" do
      mapping = described_class::ERROR_MAPPINGS["72"]
      expect(mapping[:category]).to eq(:network_error)
      expect(mapping[:retryable]).to be true
    end
  end
end
