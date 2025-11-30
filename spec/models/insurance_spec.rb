# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insurance, type: :model do
  describe "associations" do
    it { should belong_to(:onboarding_session) }
  end

  describe "Active Storage attachments" do
    it { should have_one_attached(:card_image_front) }
    it { should have_one_attached(:card_image_back) }
  end

  describe "validations" do
    it { should validate_presence_of(:onboarding_session) }
  end

  describe "enums" do
    it do
      should define_enum_for(:verification_status)
        .with_values(
          pending: 0,
          in_progress: 1,
          ocr_complete: 2,
          ocr_needs_review: 3,
          manual_entry: 4,
          verified: 5,
          failed: 6,
          manual_review: 7,
          self_pay: 8,
          manual_entry_complete: 9
        )
    end
  end

  describe "PHI encryption" do
    let(:insurance) do
      create(:insurance,
             subscriber_name: "John Doe",
             member_id: "MEM123",
             policy_number: "ABC123",
             group_number: "GRP001")
    end

    it "encrypts subscriber_name field" do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT subscriber_name FROM insurances WHERE id = '#{insurance.id}'"
      ).first["subscriber_name"]
      expect(raw_value).not_to eq("John Doe")
    end

    it "decrypts subscriber_name field when accessed" do
      expect(insurance.subscriber_name).to eq("John Doe")
    end

    it "encrypts member_id field" do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT member_id FROM insurances WHERE id = '#{insurance.id}'"
      ).first["member_id"]
      expect(raw_value).not_to eq("MEM123")
    end

    it "encrypts policy_number field" do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT policy_number FROM insurances WHERE id = '#{insurance.id}'"
      ).first["policy_number"]
      expect(raw_value).not_to eq("ABC123")
    end

    it "encrypts group_number field" do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT group_number FROM insurances WHERE id = '#{insurance.id}'"
      ).first["group_number"]
      expect(raw_value).not_to eq("GRP001")
    end
  end

  describe "#front_image_url" do
    context "with attached image" do
      let(:insurance) { create(:insurance, :with_front_image) }

      before do
        # Set url_options for Active Storage in test
        ActiveStorage::Current.url_options = { host: "localhost:3000" }
      end

      it "returns a presigned URL" do
        url = insurance.front_image_url

        expect(url).to be_a(String)
        expect(url).to include("localhost")
      end
    end

    context "without attached image" do
      let(:insurance) { create(:insurance) }

      it "returns nil" do
        expect(insurance.front_image_url).to be_nil
      end
    end
  end

  describe "#back_image_url" do
    context "with attached image" do
      let(:insurance) { create(:insurance, :with_card_images) }

      before do
        ActiveStorage::Current.url_options = { host: "localhost:3000" }
      end

      it "returns a presigned URL" do
        url = insurance.back_image_url

        expect(url).to be_a(String)
        expect(url).to include("localhost")
      end
    end

    context "without attached image" do
      let(:insurance) { create(:insurance) }

      it "returns nil" do
        expect(insurance.back_image_url).to be_nil
      end
    end
  end

  describe "image retention policy" do
    let(:insurance) { create(:insurance, :with_card_images) }

    context "when verification status changes to verified" do
      it "purges card images" do
        expect(insurance.card_image_front.attached?).to be true
        expect(insurance.card_image_back.attached?).to be true

        insurance.update!(verification_status: :verified)

        # Images should be queued for purging
        expect(insurance.card_image_front.attached?).to be false
        expect(insurance.card_image_back.attached?).to be false
      end
    end

    context "when verification status changes to self_pay" do
      it "purges card images" do
        expect(insurance.card_image_front.attached?).to be true

        insurance.update!(verification_status: :self_pay)

        expect(insurance.card_image_front.attached?).to be false
      end
    end

    context "when verification status changes to in_progress" do
      it "does not purge card images" do
        expect(insurance.card_image_front.attached?).to be true

        insurance.update!(verification_status: :in_progress)

        expect(insurance.card_image_front.attached?).to be true
      end
    end
  end

  describe "UUID primary key" do
    it "generates UUID for id" do
      insurance = create(:insurance)
      expect(insurance.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end

  describe "timestamps" do
    it "sets created_at and updated_at" do
      insurance = create(:insurance)
      expect(insurance.created_at).to be_present
      expect(insurance.updated_at).to be_present
    end
  end

  # Story 4.2: OCR Helper Methods
  describe "OCR scopes" do
    let!(:pending_insurance) { create(:insurance, verification_status: :pending) }
    let!(:in_progress_insurance) { create(:insurance, verification_status: :in_progress) }
    let!(:ocr_complete_insurance) { create(:insurance, :ocr_complete) }
    let!(:ocr_needs_review_insurance) { create(:insurance, :ocr_needs_review) }
    let!(:verified_insurance) { create(:insurance, :verified) }

    describe ".ocr_pending" do
      it "returns pending and in_progress insurances" do
        result = Insurance.ocr_pending
        expect(result).to include(pending_insurance, in_progress_insurance)
        expect(result).not_to include(ocr_complete_insurance, verified_insurance)
      end
    end

    describe ".ocr_completed" do
      it "returns ocr_complete and ocr_needs_review insurances" do
        result = Insurance.ocr_completed
        expect(result).to include(ocr_complete_insurance, ocr_needs_review_insurance)
        expect(result).not_to include(pending_insurance, verified_insurance)
      end
    end

    describe ".needs_ocr_review" do
      it "returns only ocr_needs_review insurances" do
        result = Insurance.needs_ocr_review
        expect(result).to include(ocr_needs_review_insurance)
        expect(result).not_to include(ocr_complete_insurance, pending_insurance)
      end
    end
  end

  describe "OCR helper methods" do
    describe "#ocr_data" do
      context "with OCR data" do
        let(:insurance) { create(:insurance, :ocr_complete) }

        it "returns nil (raw data not stored in ocr_complete trait)" do
          # Note: The trait doesn't include ocr_raw, so this returns nil
          expect(insurance.ocr_data).to be_nil
        end
      end

      context "without OCR data" do
        let(:insurance) { create(:insurance) }

        it "returns nil" do
          expect(insurance.ocr_data).to be_nil
        end
      end
    end

    describe "#ocr_extracted" do
      context "with OCR extraction" do
        let(:insurance) { create(:insurance, :ocr_complete) }

        it "returns extracted fields" do
          expect(insurance.ocr_extracted).to include(
            "member_id" => "MEM123456789",
            "group_number" => "GRP001"
          )
        end
      end

      context "without OCR data" do
        let(:insurance) { create(:insurance) }

        it "returns nil" do
          expect(insurance.ocr_extracted).to be_nil
        end
      end
    end

    describe "#ocr_confidence" do
      let(:insurance) { create(:insurance, :ocr_complete) }

      it "returns confidence scores" do
        expect(insurance.ocr_confidence["member_id"]).to eq(95.5)
        expect(insurance.ocr_confidence["group_number"]).to eq(92.3)
      end
    end

    describe "#ocr_low_confidence_fields" do
      context "with high confidence" do
        let(:insurance) { create(:insurance, :ocr_complete) }

        it "returns empty array" do
          expect(insurance.ocr_low_confidence_fields).to eq([])
        end
      end

      context "with low confidence fields" do
        let(:insurance) { create(:insurance, :ocr_needs_review) }

        it "returns low confidence field names" do
          expect(insurance.ocr_low_confidence_fields).to include("group_number", "payer_name")
        end
      end
    end

    describe "#needs_ocr_review?" do
      context "with ocr_needs_review status" do
        let(:insurance) { create(:insurance, :ocr_needs_review) }

        it "returns true" do
          expect(insurance.needs_ocr_review?).to be true
        end
      end

      context "with ocr_complete status" do
        let(:insurance) { create(:insurance, :ocr_complete) }

        it "returns false" do
          expect(insurance.needs_ocr_review?).to be false
        end
      end
    end

    describe "#ocr_completed_at" do
      let(:insurance) { create(:insurance, :ocr_complete) }

      it "returns completion timestamp as Time" do
        expect(insurance.ocr_completed_at).to be_a(Time)
      end
    end

    describe "#ocr_processed?" do
      context "with ocr_complete status" do
        let(:insurance) { create(:insurance, :ocr_complete) }

        it "returns true" do
          expect(insurance.ocr_processed?).to be true
        end
      end

      context "with ocr_needs_review status" do
        let(:insurance) { create(:insurance, :ocr_needs_review) }

        it "returns true" do
          expect(insurance.ocr_processed?).to be true
        end
      end

      context "with pending status" do
        let(:insurance) { create(:insurance) }

        it "returns false" do
          expect(insurance.ocr_processed?).to be false
        end
      end
    end

    describe "#ocr_error" do
      context "with OCR failure" do
        let(:insurance) { create(:insurance, :ocr_failed) }

        it "returns error details" do
          expect(insurance.ocr_error["code"]).to eq("TIMEOUT")
          expect(insurance.ocr_error["message"]).to include("timed out")
        end
      end

      context "without error" do
        let(:insurance) { create(:insurance, :ocr_complete) }

        it "returns nil" do
          expect(insurance.ocr_error).to be_nil
        end
      end
    end
  end

  # Story 4.3: Manual Entry Validations
  describe "manual entry validations" do
    describe "member_id validation" do
      it "allows valid alphanumeric member_id (6-20 chars)" do
        insurance = build(:insurance, member_id: "ABC123456")
        expect(insurance).to be_valid
      end

      it "allows blank member_id (partial save)" do
        insurance = build(:insurance, member_id: nil)
        expect(insurance).to be_valid
      end

      it "rejects member_id shorter than 6 characters" do
        insurance = build(:insurance, member_id: "ABC12")
        expect(insurance).not_to be_valid
        expect(insurance.errors[:member_id]).to include("must be 6-20 alphanumeric characters")
      end

      it "rejects member_id longer than 20 characters" do
        insurance = build(:insurance, member_id: "A" * 21)
        expect(insurance).not_to be_valid
        expect(insurance.errors[:member_id]).to include("must be 6-20 alphanumeric characters")
      end

      it "rejects member_id with special characters" do
        insurance = build(:insurance, member_id: "ABC-123-456")
        expect(insurance).not_to be_valid
        expect(insurance.errors[:member_id]).to include("must be 6-20 alphanumeric characters")
      end
    end

    describe "group_number validation" do
      it "allows valid alphanumeric group_number (4-15 chars)" do
        insurance = build(:insurance, group_number: "GRP001")
        expect(insurance).to be_valid
      end

      it "allows blank group_number (partial save)" do
        insurance = build(:insurance, group_number: nil)
        expect(insurance).to be_valid
      end

      it "rejects group_number shorter than 4 characters" do
        insurance = build(:insurance, group_number: "GRP")
        expect(insurance).not_to be_valid
        expect(insurance.errors[:group_number]).to include("must be 4-15 alphanumeric characters")
      end

      it "rejects group_number longer than 15 characters" do
        insurance = build(:insurance, group_number: "G" * 16)
        expect(insurance).not_to be_valid
        expect(insurance.errors[:group_number]).to include("must be 4-15 alphanumeric characters")
      end

      it "rejects group_number with special characters" do
        insurance = build(:insurance, group_number: "GRP-001")
        expect(insurance).not_to be_valid
        expect(insurance.errors[:group_number]).to include("must be 4-15 alphanumeric characters")
      end
    end

    describe "payer_name validation" do
      it "allows known payer names" do
        insurance = build(:insurance, payer_name: "Blue Cross Blue Shield")
        expect(insurance).to be_valid
      end

      it "allows 'Other' as payer name" do
        insurance = build(:insurance, payer_name: "Other")
        expect(insurance).to be_valid
      end

      it "allows blank payer_name (partial save)" do
        insurance = build(:insurance, payer_name: nil)
        expect(insurance).to be_valid
      end

      it "rejects unknown payer names" do
        insurance = build(:insurance, payer_name: "Unknown Insurance Company")
        expect(insurance).not_to be_valid
        expect(insurance.errors[:payer_name]).to include("must be a known payer or 'Other'")
      end
    end

    describe "subscriber_dob validation" do
      it "allows valid past date" do
        insurance = build(:insurance, subscriber_dob: "1990-05-15")
        expect(insurance).to be_valid
      end

      it "allows today's date" do
        insurance = build(:insurance, subscriber_dob: Date.current.to_s)
        expect(insurance).to be_valid
      end

      it "allows blank subscriber_dob (partial save)" do
        insurance = build(:insurance, subscriber_dob: nil)
        expect(insurance).to be_valid
      end

      it "rejects future dates" do
        insurance = build(:insurance, subscriber_dob: (Date.current + 1.day).to_s)
        expect(insurance).not_to be_valid
        expect(insurance.errors[:subscriber_dob]).to include("cannot be in the future")
      end

      it "rejects invalid date format" do
        insurance = build(:insurance, subscriber_dob: "not-a-date")
        expect(insurance).not_to be_valid
        expect(insurance.errors[:subscriber_dob]).to include("must be a valid date")
      end
    end
  end

  # Story 4.3: Manual Entry Helper Methods
  describe "manual entry helper methods" do
    describe ".known_payer_names" do
      it "returns a list of known payer names" do
        names = Insurance.known_payer_names
        expect(names).to be_an(Array)
        expect(names).to include("Blue Cross Blue Shield", "Other")
      end
    end

    describe "#ocr_data_available?" do
      context "with OCR data" do
        let(:insurance) { create(:insurance, :ocr_complete) }

        it "returns true" do
          expect(insurance.ocr_data_available?).to be true
        end
      end

      context "without OCR data" do
        let(:insurance) { create(:insurance) }

        it "returns false" do
          expect(insurance.ocr_data_available?).to be false
        end
      end
    end

    describe "#pre_populate_from_ocr" do
      context "with OCR data" do
        let(:insurance) { create(:insurance, :ocr_complete) }

        it "returns hash of OCR-extracted values" do
          result = insurance.pre_populate_from_ocr
          expect(result[:payer_name]).to eq("Blue Cross Blue Shield")
          expect(result[:member_id]).to eq("MEM123456789")
          expect(result[:group_number]).to eq("GRP001")
          expect(result[:subscriber_name]).to eq("John Doe")
        end
      end

      context "without OCR data" do
        let(:insurance) { create(:insurance) }

        it "returns empty hash" do
          expect(insurance.pre_populate_from_ocr).to eq({})
        end
      end
    end
  end

  # Story 4.3: PHI encryption for subscriber_dob
  describe "subscriber_dob PHI encryption" do
    let(:insurance) do
      create(:insurance, subscriber_dob: "1990-05-15")
    end

    it "encrypts subscriber_dob field" do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT subscriber_dob FROM insurances WHERE id = '#{insurance.id}'"
      ).first["subscriber_dob"]
      expect(raw_value).not_to eq("1990-05-15")
    end

    it "decrypts subscriber_dob field when accessed" do
      expect(insurance.subscriber_dob).to eq("1990-05-15")
    end
  end

  # Story 4.4: Eligibility Verification Helper Methods
  describe "eligibility verification helper methods" do
    let(:verified_result) do
      {
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

    let(:retryable_failed_result) do
      {
        "status" => "FAILED",
        "eligible" => nil,
        "coverage" => {},
        "error" => {
          "code" => "TIMEOUT",
          "category" => "timeout",
          "message" => "Verification timed out",
          "retryable" => true
        },
        "verified_at" => Time.current.iso8601
      }
    end

    describe "#eligibility_verified?" do
      it "returns true for verified status" do
        insurance = create(:insurance, verification_status: :verified)
        expect(insurance.eligibility_verified?).to be true
      end

      it "returns false for other statuses" do
        insurance = create(:insurance, verification_status: :pending)
        expect(insurance.eligibility_verified?).to be false
      end
    end

    describe "#eligibility_failed?" do
      it "returns true for failed status" do
        insurance = create(:insurance, verification_status: :failed)
        expect(insurance.eligibility_failed?).to be true
      end

      it "returns false for verified status" do
        insurance = create(:insurance, verification_status: :verified)
        expect(insurance.eligibility_failed?).to be false
      end
    end

    describe "#needs_eligibility_review?" do
      it "returns true for manual_review status" do
        insurance = create(:insurance, verification_status: :manual_review)
        expect(insurance.needs_eligibility_review?).to be true
      end

      it "returns false for other statuses" do
        insurance = create(:insurance, verification_status: :verified)
        expect(insurance.needs_eligibility_review?).to be false
      end
    end

    describe "#eligible?" do
      it "returns true when eligible in result" do
        insurance = create(:insurance, verification_result: verified_result)
        expect(insurance.eligible?).to be true
      end

      it "returns false when not eligible in result" do
        insurance = create(:insurance, verification_result: failed_result)
        expect(insurance.eligible?).to be false
      end

      it "returns nil when no result" do
        insurance = create(:insurance, verification_result: nil)
        expect(insurance.eligible?).to be_nil
      end
    end

    describe "#mental_health_covered?" do
      it "returns true when mental health is covered" do
        insurance = create(:insurance, verification_result: verified_result)
        expect(insurance.mental_health_covered?).to be true
      end

      it "returns false when not covered" do
        insurance = create(:insurance, verification_result: failed_result)
        expect(insurance.mental_health_covered?).to be false
      end
    end

    describe "#copay_amount" do
      it "returns copay amount from result" do
        insurance = create(:insurance, verification_result: verified_result)
        expect(insurance.copay_amount).to eq(25.0)
      end

      it "returns nil when no copay in result" do
        insurance = create(:insurance, verification_result: failed_result)
        expect(insurance.copay_amount).to be_nil
      end
    end

    describe "#deductible_amount" do
      it "returns deductible amount from result" do
        insurance = create(:insurance, verification_result: verified_result)
        expect(insurance.deductible_amount).to eq(500.0)
      end
    end

    describe "#deductible_met" do
      it "returns deductible met amount from result" do
        insurance = create(:insurance, verification_result: verified_result)
        expect(insurance.deductible_met).to eq(100.0)
      end
    end

    describe "#coinsurance_percentage" do
      it "returns coinsurance percentage from result" do
        insurance = create(:insurance, verification_result: verified_result)
        expect(insurance.coinsurance_percentage).to eq(20)
      end
    end

    describe "#coverage_effective_date" do
      it "returns effective date as Date" do
        insurance = create(:insurance, verification_result: verified_result)
        expect(insurance.coverage_effective_date).to eq(Date.parse("2024-01-01"))
      end

      it "returns nil for invalid date" do
        result = verified_result.deep_dup
        result["coverage"]["effective_date"] = "invalid"
        insurance = create(:insurance, verification_result: result)
        expect(insurance.coverage_effective_date).to be_nil
      end
    end

    describe "#error_category" do
      it "returns error category from result" do
        insurance = create(:insurance, verification_result: failed_result)
        expect(insurance.error_category).to eq("invalid_member_id")
      end

      it "returns nil when no error" do
        insurance = create(:insurance, verification_result: verified_result)
        expect(insurance.error_category).to be_nil
      end
    end

    describe "#error_message" do
      it "returns error message from result" do
        insurance = create(:insurance, verification_result: failed_result)
        expect(insurance.error_message).to eq("Member ID not found")
      end
    end

    describe "#can_retry_verification?" do
      it "returns false when verified" do
        insurance = create(:insurance,
                           verification_status: :verified,
                           verification_result: verified_result)
        expect(insurance.can_retry_verification?).to be false
      end

      it "returns true when failed with retryable error" do
        insurance = create(:insurance,
                           verification_status: :failed,
                           verification_result: retryable_failed_result)
        expect(insurance.can_retry_verification?).to be true
      end

      it "returns false when failed with non-retryable error" do
        insurance = create(:insurance,
                           verification_status: :failed,
                           verification_result: failed_result)
        expect(insurance.can_retry_verification?).to be false
      end

      it "returns true when manual_review with no error" do
        insurance = create(:insurance,
                           verification_status: :manual_review,
                           verification_result: {})
        expect(insurance.can_retry_verification?).to be true
      end
    end

    describe "#cached_result_valid?" do
      it "returns true when verified_at is within 24 hours" do
        insurance = create(:insurance, verification_result: verified_result)
        expect(insurance.cached_result_valid?).to be true
      end

      it "returns false when verified_at is older than 24 hours" do
        old_result = verified_result.deep_dup
        old_result["verified_at"] = 25.hours.ago.iso8601
        insurance = create(:insurance, verification_result: old_result)
        expect(insurance.cached_result_valid?).to be false
      end

      it "returns false when no result" do
        insurance = create(:insurance, verification_result: nil)
        expect(insurance.cached_result_valid?).to be false
      end
    end

    describe "#verified_at" do
      it "returns verified_at as Time" do
        insurance = create(:insurance, verification_result: verified_result)
        expect(insurance.verified_at).to be_a(ActiveSupport::TimeWithZone)
      end

      it "returns nil when no result" do
        insurance = create(:insurance, verification_result: nil)
        expect(insurance.verified_at).to be_nil
      end
    end

    describe "#eligibility_response_id" do
      it "returns api_response_id from result" do
        insurance = create(:insurance, verification_result: verified_result)
        expect(insurance.eligibility_response_id).to eq("test-123")
      end
    end
  end

  describe "eligibility scopes" do
    let!(:pending_insurance) { create(:insurance, verification_status: :pending) }
    let!(:in_progress_insurance) { create(:insurance, verification_status: :in_progress) }
    let!(:verified_insurance) { create(:insurance, verification_status: :verified) }
    let!(:failed_insurance) { create(:insurance, verification_status: :failed) }
    let!(:manual_review_insurance) { create(:insurance, verification_status: :manual_review) }

    describe ".pending_eligibility" do
      it "returns pending and in_progress insurances" do
        result = Insurance.pending_eligibility
        expect(result).to include(pending_insurance, in_progress_insurance)
        expect(result).not_to include(verified_insurance, failed_insurance)
      end
    end

    describe ".eligibility_verified" do
      it "returns only verified insurances" do
        result = Insurance.eligibility_verified
        expect(result).to include(verified_insurance)
        expect(result).not_to include(pending_insurance, failed_insurance)
      end
    end

    describe ".eligibility_failed" do
      it "returns only failed insurances" do
        result = Insurance.eligibility_failed
        expect(result).to include(failed_insurance)
        expect(result).not_to include(verified_insurance, pending_insurance)
      end
    end

    describe ".needs_eligibility_review" do
      it "returns only manual_review insurances" do
        result = Insurance.needs_eligibility_review
        expect(result).to include(manual_review_insurance)
        expect(result).not_to include(verified_insurance, failed_insurance)
      end
    end
  end
end

# Story 6.4: Deductible and OOP tracking methods
describe 'deductible and OOP tracking' do
  let(:insurance) { create(:insurance, :verified) }

  describe '#out_of_pocket_max_amount' do
    context 'with OOP max in verification result' do
      before do
        insurance.verification_result = {
          "coverage" => {
            "out_of_pocket_max" => { "amount" => 3000.0 }
          }
        }
      end

      it 'returns OOP max amount' do
        expect(insurance.out_of_pocket_max_amount).to eq(3000.0)
      end
    end

    context 'with family plan' do
      before do
        insurance.verification_result = {
          "coverage" => {
            "family_deductible" => { "amount" => 1000.0 },
            "family_out_of_pocket_max" => { "amount" => 5000.0 }
          }
        }
      end

      it 'returns family OOP max' do
        expect(insurance.out_of_pocket_max_amount).to eq(5000.0)
      end
    end

    context 'with manual override' do
      before do
        insurance.verification_result = {
          "coverage" => {
            "out_of_pocket_max" => { "amount" => 3000.0 }
          },
          "deductible_override" => {
            "oop_max_amount" => 3500.0
          }
        }
      end

      it 'prioritizes manual override' do
        expect(insurance.out_of_pocket_max_amount).to eq(3500.0)
      end
    end
  end

  describe '#out_of_pocket_met' do
    before do
      insurance.verification_result = {
        "coverage" => {
          "out_of_pocket_max" => { "met" => 500.0 }
        }
      }
    end

    it 'returns OOP met amount' do
      expect(insurance.out_of_pocket_met).to eq(500.0)
    end
  end

  describe '#out_of_pocket_remaining' do
    before do
      insurance.verification_result = {
        "coverage" => {
          "out_of_pocket_max" => {
            "amount" => 3000.0,
            "met" => 500.0
          }
        }
      }
    end

    it 'calculates OOP remaining' do
      expect(insurance.out_of_pocket_remaining).to eq(2500.0)
    end

    it 'returns zero if OOP max is met' do
      insurance.verification_result["coverage"]["out_of_pocket_max"]["met"] = 3000.0
      expect(insurance.out_of_pocket_remaining).to eq(0.0)
    end

    it 'does not return negative values' do
      insurance.verification_result["coverage"]["out_of_pocket_max"]["met"] = 3500.0
      expect(insurance.out_of_pocket_remaining).to eq(0.0)
    end
  end

  describe '#is_family_plan?' do
    it 'returns true for family deductible' do
      insurance.verification_result = {
        "coverage" => {
          "family_deductible" => { "amount" => 1000.0 }
        }
      }
      expect(insurance.is_family_plan?).to be true
    end

    it 'returns true for family OOP max' do
      insurance.verification_result = {
        "coverage" => {
          "family_out_of_pocket_max" => { "amount" => 5000.0 }
        }
      }
      expect(insurance.is_family_plan?).to be true
    end

    it 'returns true for member_count > 1' do
      insurance.verification_result = {
        "coverage" => {
          "member_count" => 3
        }
      }
      expect(insurance.is_family_plan?).to be true
    end

    it 'returns true for has_dependents flag' do
      insurance.verification_result = {
        "coverage" => {
          "has_dependents" => true
        }
      }
      expect(insurance.is_family_plan?).to be true
    end

    it 'returns false for individual plan' do
      insurance.verification_result = {
        "coverage" => {
          "deductible" => { "amount" => 500.0 }
        }
      }
      expect(insurance.is_family_plan?).to be false
    end
  end

  describe '#plan_year_reset_date' do
    it 'returns next reset date from plan year start' do
      insurance.verification_result = {
        "coverage" => {
          "plan_year_start" => "2025-07-01"
        }
      }

      travel_to Date.new(2025, 11, 30) do
        expect(insurance.plan_year_reset_date).to eq(Date.new(2026, 7, 1))
      end
    end

    it 'returns current year anniversary if not passed' do
      insurance.verification_result = {
        "coverage" => {
          "plan_year_start" => "2025-12-15"
        }
      }

      travel_to Date.new(2025, 11, 30) do
        expect(insurance.plan_year_reset_date).to eq(Date.new(2025, 12, 15))
      end
    end

    it 'defaults to next January 1' do
      insurance.verification_result = { "coverage" => {} }

      travel_to Date.new(2025, 11, 30) do
        expect(insurance.plan_year_reset_date).to eq(Date.new(2026, 1, 1))
      end
    end
  end
end
