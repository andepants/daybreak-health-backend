# frozen_string_literal: true

require "rails_helper"

RSpec.describe InsuranceServices::StatusMessageService do
  let(:onboarding_session) { create(:onboarding_session) }
  let(:insurance) { create(:insurance, onboarding_session: onboarding_session) }

  subject(:service) { described_class.new(insurance) }

  describe "#generate_display" do
    it "returns a hash with all display components" do
      result = service.generate_display

      expect(result).to include(
        :status_display,
        :message,
        :why_explanation,
        :next_steps,
        :can_retry,
        :support_contact,
        :self_pay_option
      )
    end
  end

  describe "#status_display_text" do
    context "when insurance is verified" do
      before { insurance.update!(verification_status: :verified) }

      it "returns 'Verified'" do
        expect(service.status_display_text).to eq("Verified")
      end
    end

    context "when insurance is self_pay" do
      before { insurance.update!(verification_status: :self_pay) }

      it "returns 'Self-Pay Selected'" do
        expect(service.status_display_text).to eq("Self-Pay Selected")
      end
    end

    context "when insurance is pending" do
      before { insurance.update!(verification_status: :pending) }

      it "returns 'Checking...'" do
        expect(service.status_display_text).to eq("Checking...")
      end
    end

    context "when insurance is in_progress" do
      before { insurance.update!(verification_status: :in_progress) }

      it "returns 'Checking...'" do
        expect(service.status_display_text).to eq("Checking...")
      end
    end

    context "when insurance failed with low severity error" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "NETWORK_ERROR" } }
        )
      end

      it "returns 'Needs Attention'" do
        expect(service.status_display_text).to eq("Needs Attention")
      end
    end

    context "when insurance failed with high severity error" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "COVERAGE_INACTIVE" } }
        )
      end

      it "returns 'Unable to Verify'" do
        expect(service.status_display_text).to eq("Unable to Verify")
      end
    end

    context "when insurance needs manual review" do
      before { insurance.update!(verification_status: :manual_review) }

      it "returns 'Needs Attention'" do
        expect(service.status_display_text).to eq("Needs Attention")
      end
    end

    context "when insurance OCR is complete" do
      before { insurance.update!(verification_status: :ocr_complete) }

      it "returns 'Ready for Verification'" do
        expect(service.status_display_text).to eq("Ready for Verification")
      end
    end
  end

  describe "#plain_language_message" do
    context "when insurance is verified" do
      before { insurance.update!(verification_status: :verified) }

      it "returns success message" do
        expect(service.plain_language_message).to eq("Your insurance is verified and active!")
      end
    end

    context "when insurance is self_pay" do
      before { insurance.update!(verification_status: :self_pay) }

      it "returns self-pay message" do
        expect(service.plain_language_message).to include("pay out of pocket")
      end
    end

    context "when error code is INVALID_MEMBER_ID" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "INVALID_MEMBER_ID" } }
        )
      end

      it "returns user-friendly message" do
        expect(service.plain_language_message).to include("member ID")
      end
    end

    context "when error code is COVERAGE_INACTIVE" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "COVERAGE_INACTIVE" } }
        )
      end

      it "returns user-friendly message about inactive coverage" do
        expect(service.plain_language_message).to include("isn't currently active")
      end
    end

    context "when error code is SERVICE_NOT_COVERED" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "SERVICE_NOT_COVERED" } }
        )
      end

      it "returns user-friendly message about uncovered services" do
        expect(service.plain_language_message).to include("Mental health services")
      end
    end

    context "when error code is NETWORK_ERROR" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "NETWORK_ERROR" } }
        )
      end

      it "returns user-friendly message about connection issue" do
        expect(service.plain_language_message).to include("trouble connecting")
      end
    end

    context "when error code is unknown" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "UNKNOWN_ERROR" } }
        )
      end

      it "returns generic message" do
        expect(service.plain_language_message).to include("encountered an issue")
      end
    end
  end

  describe "#why_explanation" do
    context "when insurance is verified" do
      before { insurance.update!(verification_status: :verified) }

      it "returns nil" do
        expect(service.why_explanation).to be_nil
      end
    end

    context "when insurance is self_pay" do
      before { insurance.update!(verification_status: :self_pay) }

      it "returns nil" do
        expect(service.why_explanation).to be_nil
      end
    end

    context "when error code has explanation" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "INVALID_MEMBER_ID" } }
        )
      end

      it "returns why explanation" do
        expect(service.why_explanation).to include("doesn't match records")
      end
    end
  end

  describe "#can_retry?" do
    context "when insurance is verified" do
      before { insurance.update!(verification_status: :verified) }

      it "returns false" do
        expect(service.can_retry?).to be false
      end
    end

    context "when insurance is self_pay" do
      before { insurance.update!(verification_status: :self_pay) }

      it "returns false" do
        expect(service.can_retry?).to be false
      end
    end

    context "when retry_attempts >= 3" do
      before do
        insurance.update!(
          verification_status: :failed,
          retry_attempts: 3
        )
      end

      it "returns false" do
        expect(service.can_retry?).to be false
      end
    end

    context "when error is marked as not retryable" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "NETWORK_ERROR", "retryable" => false } }
        )
      end

      it "returns false" do
        expect(service.can_retry?).to be false
      end
    end

    context "when error is high severity" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "COVERAGE_INACTIVE" } }
        )
      end

      it "returns false" do
        expect(service.can_retry?).to be false
      end
    end

    context "when error is low severity and retryable" do
      before do
        insurance.update!(
          verification_status: :failed,
          retry_attempts: 1,
          verification_result: { "error" => { "code" => "NETWORK_ERROR" } }
        )
      end

      it "returns true" do
        expect(service.can_retry?).to be true
      end
    end

    context "when error is medium severity" do
      before do
        insurance.update!(
          verification_status: :failed,
          retry_attempts: 1,
          verification_result: { "error" => { "code" => "INVALID_MEMBER_ID" } }
        )
      end

      it "returns true" do
        expect(service.can_retry?).to be true
      end
    end
  end

  describe "#generate_next_steps" do
    context "when insurance is verified" do
      before { insurance.update!(verification_status: :verified) }

      it "returns next steps for verified status" do
        steps = service.generate_next_steps

        expect(steps).to include("Continue to your child's assessment")
        expect(steps).to include("Review your coverage details below")
      end
    end

    context "when insurance is self_pay" do
      before { insurance.update!(verification_status: :self_pay) }

      it "returns next steps for self-pay" do
        steps = service.generate_next_steps

        expect(steps).to include("Continue to your child's assessment")
        expect(steps).to include(/self-pay/i)
      end
    end

    context "when can retry with data error" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "INVALID_MEMBER_ID" } }
        )
      end

      it "includes correction steps" do
        steps = service.generate_next_steps

        expect(steps).to include(/check/i)
        expect(steps).to include(/self-pay/i)
      end
    end

    context "when cannot retry" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "COVERAGE_INACTIVE" } }
        )
      end

      it "includes alternative paths" do
        steps = service.generate_next_steps

        expect(steps).to include(/self-pay/i)
        expect(steps.any? { |s| s.include?("insurance company") || s.include?("support") }).to be true
      end
    end

    it "always includes at least one next step" do
      expect(service.generate_next_steps).not_to be_empty
    end
  end

  describe "#support_contact" do
    context "when error is high severity" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "COVERAGE_INACTIVE" } }
        )
      end

      it "returns specialist contact" do
        contact = service.support_contact

        expect(contact[:type]).to eq("specialist")
        expect(contact[:phone]).to be_present
        expect(contact[:email]).to be_present
        expect(contact[:hours]).to be_present
      end
    end

    context "when error is low severity" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "NETWORK_ERROR" } }
        )
      end

      it "returns general contact" do
        contact = service.support_contact

        expect(contact[:type]).to eq("general")
      end
    end

    context "when retry attempts exhausted" do
      before do
        insurance.update!(
          verification_status: :failed,
          retry_attempts: 3,
          verification_result: { "error" => { "code" => "NETWORK_ERROR" } }
        )
      end

      it "returns specialist contact" do
        contact = service.support_contact

        expect(contact[:type]).to eq("specialist")
      end
    end
  end

  describe "#self_pay_option" do
    it "always returns available as true" do
      expect(service.self_pay_option[:available]).to be true
    end

    it "includes description" do
      expect(service.self_pay_option[:description]).to be_present
    end

    it "includes preview rate" do
      expect(service.self_pay_option[:preview_rate]).to be_present
    end

    context "when insurance is verified" do
      before { insurance.update!(verification_status: :verified) }

      it "still returns self-pay option" do
        expect(service.self_pay_option[:available]).to be true
      end
    end

    context "when insurance failed" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "COVERAGE_INACTIVE" } }
        )
      end

      it "returns self-pay option" do
        expect(service.self_pay_option[:available]).to be true
      end
    end
  end
end
