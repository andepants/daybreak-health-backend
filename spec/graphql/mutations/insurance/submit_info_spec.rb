# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Insurance::SubmitInfo, type: :graphql do
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
            ocrDataAvailable
          }
          prePopulatedFromOcr
          errors {
            field
            message
          }
        }
      }
    GQL
  end

  describe "successful manual entry" do
    it "creates insurance with all valid fields" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          payerName: "Blue Cross Blue Shield",
          memberId: "ABC123456789",
          groupNumber: "GRP001234",
          subscriberName: "Jane Doe",
          subscriberDob: "1985-06-15"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to be_empty
      expect(data["insurance"]).to be_present
      expect(data["insurance"]["payerName"]).to eq("Blue Cross Blue Shield")
      expect(data["insurance"]["memberId"]).to eq("ABC123456789")
      expect(data["insurance"]["groupNumber"]).to eq("GRP001234")
      expect(data["insurance"]["subscriberName"]).to eq("Jane Doe")
      expect(data["insurance"]["subscriberDob"]).to eq("1985-06-15")
      expect(data["insurance"]["verificationStatus"]).to eq("manual_entry_complete")
      expect(data["prePopulatedFromOcr"]).to be false
    end

    it "allows partial save (some fields only)" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          payerName: "Aetna"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to be_empty
      expect(data["insurance"]["payerName"]).to eq("Aetna")
      expect(data["insurance"]["memberId"]).to be_nil
    end

    it "updates existing insurance record" do
      insurance = create(:insurance, onboarding_session: session, payer_name: "Other")

      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          payerName: "Cigna",
          memberId: "NEW123456789"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to be_empty
      expect(data["insurance"]["id"]).to eq(insurance.id)
      expect(data["insurance"]["payerName"]).to eq("Cigna")
      expect(data["insurance"]["memberId"]).to eq("NEW123456789")
    end

    it "sets status to manual_entry_complete when member_id and payer_name are present" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          payerName: "UnitedHealthcare",
          memberId: "MEM123456"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["insurance"]["verificationStatus"]).to eq("manual_entry_complete")
    end

    it "creates audit log entry" do
      expect {
        execute_graphql(
          mutation,
          variables: {
            sessionId: session_id,
            payerName: "Blue Cross Blue Shield",
            memberId: "ABC123456789"
          }
        )
      }.to change(AuditLog, :count)

      audit_log = AuditLog.find_by(action: "INSURANCE_MANUAL_ENTRY")
      expect(audit_log).to be_present
      expect(audit_log.resource).to eq("Insurance")
      expect(audit_log.onboarding_session_id).to eq(session.id)
      expect(audit_log.details["fields_updated"]).to include("payer_name", "member_id")
    end
  end

  describe "validation errors" do
    it "returns error for invalid member_id (too short)" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          payerName: "Aetna",
          memberId: "ABC"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["insurance"]).to be_nil
      expect(data["errors"]).to include(
        a_hash_including("field" => "member_id", "message" => "must be 6-20 alphanumeric characters")
      )
    end

    it "returns error for invalid member_id (too long)" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          memberId: "A" * 21
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to include(
        a_hash_including("field" => "member_id")
      )
    end

    it "returns error for invalid member_id (special characters)" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          memberId: "ABC-123-456"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to include(
        a_hash_including("field" => "member_id", "message" => "must be 6-20 alphanumeric characters")
      )
    end

    it "returns error for invalid group_number (too short)" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          groupNumber: "GRP"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to include(
        a_hash_including("field" => "group_number", "message" => "must be 4-15 alphanumeric characters")
      )
    end

    it "returns error for invalid group_number (too long)" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          groupNumber: "G" * 16
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to include(
        a_hash_including("field" => "group_number")
      )
    end

    it "returns error for unknown payer_name" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          payerName: "Unknown Insurance Company"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to include(
        a_hash_including("field" => "payer_name", "message" => "must be a known payer or 'Other'")
      )
    end

    it "returns error for future subscriber_dob" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          subscriberDob: (Date.current + 1.day).to_s
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to include(
        a_hash_including("field" => "subscriber_dob", "message" => "cannot be in the future")
      )
    end

    it "returns error for invalid subscriber_dob format" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          subscriberDob: "not-a-date"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to include(
        a_hash_including("field" => "subscriber_dob", "message" => "must be a valid date")
      )
    end
  end

  describe "OCR pre-population" do
    let!(:insurance_with_ocr) { create(:insurance, :ocr_complete, onboarding_session: session) }

    it "indicates OCR data was available" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          payerName: "Cigna",
          memberId: "NEW123456789"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["prePopulatedFromOcr"]).to be true
    end

    it "manual values override OCR values" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          payerName: "Humana",
          memberId: "MANUAL123456"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["insurance"]["payerName"]).to eq("Humana")
      expect(data["insurance"]["memberId"]).to eq("MANUAL123456")
    end

    it "tracks data sources in verification_result" do
      execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          payerName: "Kaiser Permanente",
          memberId: "KP12345678"
        }
      )

      insurance = session.reload.insurance
      data_sources = insurance.verification_result["data_sources"]
      expect(data_sources["payer_name"]).to eq("manual")
      expect(data_sources["member_id"]).to eq("manual")
    end
  end

  describe "session handling" do
    it "returns error for non-existent session" do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: "sess_00000000000000000000000000000000",
          payerName: "Aetna"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to include(
        a_hash_including("field" => "session_id", "message" => "Session not found")
      )
    end

    it "returns error for expired session" do
      session.update!(expires_at: 1.hour.ago)

      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          payerName: "Aetna"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to include(
        a_hash_including("field" => "session_id", "message" => "Session has expired")
      )
    end
  end

  describe "partial save (skip) functionality" do
    it "allows saving with minimal fields" do
      create(:insurance, onboarding_session: session, payer_name: "Other")

      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["errors"]).to be_empty
      expect(data["insurance"]).to be_present
    end

    it "preserves existing values when not provided" do
      create(:insurance,
             onboarding_session: session,
             payer_name: "Aetna",
             member_id: "ABC1234567",
             group_number: "GRP0001")

      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          subscriberName: "John Smith"
        }
      )

      data = result.dig("data", "submitInsuranceInfo")
      expect(data["insurance"]["payerName"]).to eq("Aetna")
      expect(data["insurance"]["memberId"]).to eq("ABC1234567")
      expect(data["insurance"]["groupNumber"]).to eq("GRP0001")
      expect(data["insurance"]["subscriberName"]).to eq("John Smith")
    end
  end
end
