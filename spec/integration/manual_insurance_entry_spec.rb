# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Manual Insurance Entry Flow", type: :integration do
  let(:session) { create(:onboarding_session, status: :in_progress) }
  let(:session_id) { "sess_#{session.id.gsub('-', '')}" }

  let(:mutation) do
    <<~GQL
      mutation SubmitInsuranceInfo(
        $sessionId: ID!,
        $payerName: String,
        $memberId: String,
        $groupNumber: String,
        $subscriberName: String,
        $subscriberDob: String
      ) {
        submitInsuranceInfo(
          sessionId: $sessionId,
          payerName: $payerName,
          memberId: $memberId,
          groupNumber: $groupNumber,
          subscriberName: $subscriberName,
          subscriberDob: $subscriberDob
        ) {
          insurance {
            id
            payerName
            memberId
            groupNumber
            subscriberName
            subscriberDob
            verificationStatus
          }
          prePopulatedFromOcr
          errors { field message }
        }
      }
    GQL
  end

  describe "complete flow: no insurance → manual entry → status updated" do
    it "creates insurance via manual entry from scratch" do
      # Initially no insurance
      expect(session.insurance).to be_nil

      # Submit manual entry
      result = execute_graphql(mutation, variables: {
        sessionId: session_id,
        payerName: "Blue Cross Blue Shield",
        memberId: "BCBS123456789",
        groupNumber: "GRP001234",
        subscriberName: "Jane Smith",
        subscriberDob: "1980-03-25"
      })

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to be_empty
      expect(data["insurance"]["verificationStatus"]).to eq("manual_entry_complete")

      # Verify persisted
      insurance = session.reload.insurance
      expect(insurance).to be_present
      expect(insurance.payer_name).to eq("Blue Cross Blue Shield")
      expect(insurance.member_id).to eq("BCBS123456789")
      expect(insurance.group_number).to eq("GRP001234")
      expect(insurance.subscriber_name).to eq("Jane Smith")
      expect(insurance.subscriber_dob).to eq("1980-03-25")
      expect(insurance.manual_entry_complete?).to be true

      # Verify audit trail
      audit = AuditLog.find_by(action: "INSURANCE_MANUAL_ENTRY")
      expect(audit).to be_present
      expect(audit.details["fields_updated"]).to match_array(
        %w[payer_name member_id group_number subscriber_name subscriber_dob]
      )
    end
  end

  describe "flow: OCR extraction → manual correction → status updated" do
    it "allows manual correction of OCR-extracted values" do
      # Create insurance with OCR data
      insurance = create(:insurance, :ocr_complete, onboarding_session: session)
      expect(insurance.ocr_data_available?).to be true

      # OCR extracted "Blue Cross Blue Shield" but user wants to correct it
      result = execute_graphql(mutation, variables: {
        sessionId: session_id,
        payerName: "Cigna",
        memberId: "CIGNA9876543"
      })

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to be_empty
      expect(data["prePopulatedFromOcr"]).to be true
      expect(data["insurance"]["payerName"]).to eq("Cigna")
      expect(data["insurance"]["memberId"]).to eq("CIGNA9876543")
      expect(data["insurance"]["verificationStatus"]).to eq("manual_entry_complete")

      # Verify data sources track manual override
      insurance.reload
      expect(insurance.verification_result["data_sources"]["payer_name"]).to eq("manual")
      expect(insurance.verification_result["data_sources"]["member_id"]).to eq("manual")
    end
  end

  describe "skip and return later scenario" do
    it "allows partial save then complete later" do
      # First: partial save with just payer name
      result1 = execute_graphql(mutation, variables: {
        sessionId: session_id,
        payerName: "Humana"
      })

      data1 = result1.dig("data", "submitInsuranceInfo")
      expect(data1["errors"]).to be_empty
      expect(data1["insurance"]["payerName"]).to eq("Humana")
      expect(data1["insurance"]["memberId"]).to be_nil
      # Not complete yet - missing member_id
      expect(data1["insurance"]["verificationStatus"]).not_to eq("manual_entry_complete")

      insurance_id = data1["insurance"]["id"]

      # Second: complete the entry
      result2 = execute_graphql(mutation, variables: {
        sessionId: session_id,
        memberId: "HUM123456789"
      })

      data2 = result2.dig("data", "submitInsuranceInfo")
      expect(data2["errors"]).to be_empty
      expect(data2["insurance"]["id"]).to eq(insurance_id)
      expect(data2["insurance"]["payerName"]).to eq("Humana")
      expect(data2["insurance"]["memberId"]).to eq("HUM123456789")
      expect(data2["insurance"]["verificationStatus"]).to eq("manual_entry_complete")
    end
  end

  describe "status transitions" do
    it "correctly transitions from pending to manual_entry_complete" do
      create(:insurance, onboarding_session: session, verification_status: :pending)

      result = execute_graphql(mutation, variables: {
        sessionId: session_id,
        payerName: "Aetna",
        memberId: "AETNA123456"
      })

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["insurance"]["verificationStatus"]).to eq("manual_entry_complete")
    end

    it "correctly transitions from ocr_complete to manual_entry_complete" do
      create(:insurance, :ocr_complete, onboarding_session: session)

      result = execute_graphql(mutation, variables: {
        sessionId: session_id,
        payerName: "UnitedHealthcare",
        memberId: "UHC987654321"
      })

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["insurance"]["verificationStatus"]).to eq("manual_entry_complete")
    end

    it "correctly transitions from ocr_needs_review to manual_entry_complete" do
      create(:insurance, :ocr_needs_review, onboarding_session: session)

      result = execute_graphql(mutation, variables: {
        sessionId: session_id,
        payerName: "Kaiser Permanente",
        memberId: "KP123456789"
      })

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["insurance"]["verificationStatus"]).to eq("manual_entry_complete")
    end
  end
end
