# frozen_string_literal: true

require "rails_helper"

RSpec.describe InsuranceServices::CoverageFormatter do
  let(:onboarding_session) { create(:onboarding_session) }
  let(:insurance) { create(:insurance, onboarding_session: onboarding_session) }

  subject(:formatter) { described_class.new(insurance) }

  describe "#format_all" do
    context "when insurance is not verified" do
      before { insurance.update!(verification_status: :pending) }

      it "returns nil" do
        expect(formatter.format_all).to be_nil
      end
    end

    context "when insurance is verified" do
      before do
        insurance.update!(
          verification_status: :verified,
          verification_result: {
            "coverage" => {
              "copay" => { "amount" => 25 },
              "deductible" => { "amount" => 500, "met" => 100 },
              "coinsurance" => { "percentage" => 20 },
              "effective_date" => "2024-01-01"
            }
          }
        )
      end

      it "returns formatted coverage details" do
        result = formatter.format_all

        expect(result).to include(
          :copay_amount,
          :services_covered,
          :effective_date,
          :deductible,
          :coinsurance
        )
      end
    end
  end

  describe "#format_copay" do
    context "when copay is present" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "copay" => { "amount" => 25 } }
          }
        )
      end

      it "formats as currency per visit" do
        expect(formatter.format_copay).to eq("$25 per visit")
      end
    end

    context "when copay has custom frequency" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "copay" => { "amount" => 50, "frequency" => "session" } }
          }
        )
      end

      it "uses custom frequency" do
        expect(formatter.format_copay).to eq("$50 per session")
      end
    end

    context "when copay has decimal amount" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "copay" => { "amount" => 25.50 } }
          }
        )
      end

      it "formats with decimals" do
        expect(formatter.format_copay).to eq("$25.50 per visit")
      end
    end

    context "when copay is nil" do
      before do
        insurance.update!(verification_result: { "coverage" => {} })
      end

      it "returns nil" do
        expect(formatter.format_copay).to be_nil
      end
    end
  end

  describe "#format_deductible" do
    context "when deductible has met amount" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "deductible" => { "amount" => 500, "met" => 100 } }
          }
        )
      end

      it "formats with met amount" do
        expect(formatter.format_deductible).to eq("$500 ($100 met)")
      end
    end

    context "when deductible has remaining amount" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "deductible" => { "amount" => 500, "remaining" => 400 } }
          }
        )
      end

      it "formats with remaining amount" do
        expect(formatter.format_deductible).to eq("$500 ($400 remaining)")
      end
    end

    context "when deductible has only amount" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "deductible" => { "amount" => 500 } }
          }
        )
      end

      it "formats with just amount" do
        expect(formatter.format_deductible).to eq("$500")
      end
    end

    context "when deductible is nil" do
      before do
        insurance.update!(verification_result: { "coverage" => {} })
      end

      it "returns nil" do
        expect(formatter.format_deductible).to be_nil
      end
    end
  end

  describe "#format_services" do
    context "when services are provided" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => {
              "services_covered" => ["Therapy", "Counseling", "Psychiatric care"]
            }
          }
        )
      end

      it "returns the services array" do
        expect(formatter.format_services).to eq(["Therapy", "Counseling", "Psychiatric care"])
      end
    end

    context "when services are nil" do
      before do
        insurance.update!(verification_result: { "coverage" => {} })
      end

      it "returns default services" do
        expect(formatter.format_services).to include("Mental health services")
        expect(formatter.format_services).to include("Individual therapy")
      end
    end

    context "when services are empty" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "services_covered" => [] }
          }
        )
      end

      it "returns default services" do
        expect(formatter.format_services).to include("Mental health services")
      end
    end
  end

  describe "#format_effective_date" do
    context "when date is present" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "effective_date" => "2024-01-15" }
          }
        )
      end

      it "formats as readable date" do
        expect(formatter.format_effective_date).to eq("January 15, 2024")
      end
    end

    context "when date is nil" do
      before do
        insurance.update!(verification_result: { "coverage" => {} })
      end

      it "returns nil" do
        expect(formatter.format_effective_date).to be_nil
      end
    end

    context "when date is invalid" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "effective_date" => "not-a-date" }
          }
        )
      end

      it "returns nil" do
        expect(formatter.format_effective_date).to be_nil
      end
    end
  end

  describe "#format_coinsurance" do
    context "when coinsurance is present" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "coinsurance" => { "percentage" => 20 } }
          }
        )
      end

      it "returns percentage as integer" do
        expect(formatter.format_coinsurance).to eq(20)
      end
    end

    context "when coinsurance is nil" do
      before do
        insurance.update!(verification_result: { "coverage" => {} })
      end

      it "returns nil" do
        expect(formatter.format_coinsurance).to be_nil
      end
    end

    context "when coinsurance is not a number" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "coinsurance" => { "percentage" => "twenty" } }
          }
        )
      end

      it "returns nil" do
        expect(formatter.format_coinsurance).to be_nil
      end
    end
  end

  describe "#format_termination_warning" do
    context "when termination is within 30 days" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "termination_date" => (Date.current + 15.days).to_s }
          }
        )
      end

      it "returns warning message" do
        warning = formatter.format_termination_warning
        expect(warning).to include("Coverage ends")
      end
    end

    context "when termination is more than 30 days away" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "termination_date" => (Date.current + 60.days).to_s }
          }
        )
      end

      it "returns nil" do
        expect(formatter.format_termination_warning).to be_nil
      end
    end

    context "when termination date is in the past" do
      before do
        insurance.update!(
          verification_result: {
            "coverage" => { "termination_date" => (Date.current - 5.days).to_s }
          }
        )
      end

      it "returns nil" do
        expect(formatter.format_termination_warning).to be_nil
      end
    end

    context "when termination date is nil" do
      before do
        insurance.update!(verification_result: { "coverage" => {} })
      end

      it "returns nil" do
        expect(formatter.format_termination_warning).to be_nil
      end
    end
  end
end
