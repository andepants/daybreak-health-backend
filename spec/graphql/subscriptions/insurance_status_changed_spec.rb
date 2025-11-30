# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::InsuranceStatusChanged, type: :graphql do
  let(:session) { create(:onboarding_session) }
  let!(:insurance) { create(:insurance, onboarding_session: session) }

  describe "class definition" do
    it "is a GraphQL subscription" do
      expect(described_class).to be < GraphQL::Schema::Subscription
    end

    it "has session_id argument" do
      args = described_class.arguments
      expect(args["sessionId"]).to be_present
    end

    it "has insurance field" do
      fields = described_class.fields
      expect(fields["insurance"]).to be_present
    end
  end

  describe "InsuranceType OCR fields" do
    # Test that the InsuranceType exposes the correct OCR fields

    context "with OCR complete insurance" do
      let!(:insurance) { create(:insurance, :ocr_complete, onboarding_session: session) }

      it "has correct verification status" do
        expect(insurance.verification_status).to eq("ocr_complete")
      end

      it "has OCR extracted data" do
        expect(insurance.ocr_extracted).to be_present
        expect(insurance.ocr_extracted["member_id"]).to eq("MEM123456789")
      end

      it "has OCR confidence scores" do
        expect(insurance.ocr_confidence).to be_present
        expect(insurance.ocr_confidence["member_id"]).to eq(95.5)
      end

      it "has empty low confidence fields" do
        expect(insurance.ocr_low_confidence_fields).to eq([])
      end

      it "does not need review" do
        expect(insurance.needs_ocr_review?).to be false
      end

      it "is OCR processed" do
        expect(insurance.ocr_processed?).to be true
      end

      it "has no error" do
        expect(insurance.ocr_error).to be_nil
      end
    end

    context "with OCR needs review insurance" do
      let!(:insurance) { create(:insurance, :ocr_needs_review, onboarding_session: session) }

      it "has correct verification status" do
        expect(insurance.verification_status).to eq("ocr_needs_review")
      end

      it "needs review" do
        expect(insurance.needs_ocr_review?).to be true
      end

      it "has low confidence fields" do
        expect(insurance.ocr_low_confidence_fields).to include("group_number", "payer_name")
      end
    end

    context "with failed OCR" do
      let!(:insurance) { create(:insurance, :ocr_failed, onboarding_session: session) }

      it "has correct verification status" do
        expect(insurance.verification_status).to eq("failed")
      end

      it "has error details" do
        expect(insurance.ocr_error).to be_present
        expect(insurance.ocr_error["code"]).to eq("TIMEOUT")
      end
    end
  end

  describe "InsuranceType GraphQL fields" do
    let(:insurance_type) { Types::InsuranceType }

    it "defines ocr_extracted field" do
      field = insurance_type.fields["ocrExtracted"]
      expect(field).to be_present
    end

    it "defines ocr_confidence field" do
      field = insurance_type.fields["ocrConfidence"]
      expect(field).to be_present
    end

    it "defines ocr_low_confidence_fields field" do
      field = insurance_type.fields["ocrLowConfidenceFields"]
      expect(field).to be_present
    end

    it "defines needs_review field" do
      field = insurance_type.fields["needsReview"]
      expect(field).to be_present
    end

    it "defines ocr_processed field" do
      field = insurance_type.fields["ocrProcessed"]
      expect(field).to be_present
    end

    it "defines ocr_error field" do
      field = insurance_type.fields["ocrError"]
      expect(field).to be_present
    end
  end

  describe "subscription is registered in schema" do
    it "exists in subscription type" do
      field = Types::SubscriptionType.fields["insuranceStatusChanged"]
      expect(field).to be_present
    end
  end
end
