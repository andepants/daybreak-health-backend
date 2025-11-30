# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligibility::AdapterFactory do
  let(:onboarding_session) { create(:onboarding_session) }

  describe ".adapter_for" do
    context "with a standard payer" do
      let(:insurance) do
        create(:insurance,
               onboarding_session: onboarding_session,
               payer_name: "Blue Cross Blue Shield")
      end

      it "returns an EdiAdapter instance" do
        adapter = described_class.adapter_for(insurance)

        expect(adapter).to be_a(Eligibility::EdiAdapter)
      end
    end

    context "with an 'Other' payer" do
      let(:insurance) do
        create(:insurance,
               onboarding_session: onboarding_session,
               payer_name: "Other")
      end

      it "falls back to EdiAdapter" do
        adapter = described_class.adapter_for(insurance)

        expect(adapter).to be_a(Eligibility::EdiAdapter)
      end
    end

    context "with nil payer name" do
      let(:insurance) do
        # Use build_stubbed to avoid validation, then stub payer_name
        build_stubbed(:insurance, onboarding_session: onboarding_session)
      end

      before do
        allow(insurance).to receive(:payer_name).and_return(nil)
      end

      it "falls back to EdiAdapter" do
        adapter = described_class.adapter_for(insurance)

        expect(adapter).to be_a(Eligibility::EdiAdapter)
      end
    end

    context "with blank payer name" do
      let(:insurance) do
        build_stubbed(:insurance, onboarding_session: onboarding_session)
      end

      before do
        allow(insurance).to receive(:payer_name).and_return("   ")
      end

      it "falls back to EdiAdapter" do
        adapter = described_class.adapter_for(insurance)

        expect(adapter).to be_a(Eligibility::EdiAdapter)
      end
    end
  end

  describe ".custom_adapter?" do
    it "returns false for standard payers" do
      expect(described_class.custom_adapter?("Blue Cross Blue Shield")).to be false
    end

    it "returns false for unknown payers" do
      expect(described_class.custom_adapter?("Unknown Payer")).to be false
    end

    # Future: when custom adapters are added
    # it "returns true for Aetna" do
    #   expect(described_class.custom_adapter?("Aetna")).to be true
    # end
  end

  describe ".payers_with_custom_adapters" do
    it "returns an array" do
      expect(described_class.payers_with_custom_adapters).to be_an(Array)
    end

    # Currently empty as all payers use generic EDI
    it "is empty when no custom adapters are configured" do
      expect(described_class.payers_with_custom_adapters).to be_empty
    end
  end

  describe "PAYER_ADAPTERS constant" do
    it "is a frozen hash" do
      expect(described_class::PAYER_ADAPTERS).to be_frozen
      expect(described_class::PAYER_ADAPTERS).to be_a(Hash)
    end

    it "has documented future adapter placeholders" do
      # Verify the structure is ready for future expansions
      expect(described_class::PAYER_ADAPTERS).to be_empty
      # When custom adapters are added, they should map payer names to class names
    end
  end
end
