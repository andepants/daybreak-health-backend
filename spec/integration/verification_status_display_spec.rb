# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Verification Status Display Integration" do
  let(:onboarding_session) { create(:onboarding_session) }
  let(:insurance) { create(:insurance, onboarding_session: onboarding_session) }

  # Helper to get status display data using the services
  def get_display_data(insurance)
    status_service = InsuranceServices::StatusMessageService.new(insurance)
    coverage_formatter = InsuranceServices::CoverageFormatter.new(insurance)

    display = status_service.generate_display

    {
      verification_status_display: display[:status_display],
      verification_message: display[:message],
      why_explanation: display[:why_explanation],
      next_steps: display[:next_steps],
      can_retry: display[:can_retry],
      retry_attempts: insurance.retry_attempts,
      support_contact: display[:support_contact],
      self_pay_option: display[:self_pay_option],
      coverage_details: coverage_formatter.format_all
    }
  end

  describe "AC1: Verification status display" do
    context "when status is verified" do
      before do
        insurance.update!(
          verification_status: :verified,
          verification_result: {
            "coverage" => {
              "copay" => { "amount" => 25 },
              "effective_date" => "2024-01-01"
            }
          }
        )
      end

      it "displays 'Verified'" do
        result = get_display_data(insurance)
        expect(result[:verification_status_display]).to eq("Verified")
      end
    end

    context "when status is failed with retriable error" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "NETWORK_ERROR" } }
        )
      end

      it "displays 'Needs Attention'" do
        result = get_display_data(insurance)
        expect(result[:verification_status_display]).to eq("Needs Attention")
      end
    end

    context "when status is failed with non-retriable error" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "COVERAGE_INACTIVE" } }
        )
      end

      it "displays 'Unable to Verify'" do
        result = get_display_data(insurance)
        expect(result[:verification_status_display]).to eq("Unable to Verify")
      end
    end
  end

  describe "AC2: Coverage details for verified status" do
    before do
      insurance.update!(
        verification_status: :verified,
        verification_result: {
          "coverage" => {
            "copay" => { "amount" => 25 },
            "deductible" => { "amount" => 500, "met" => 100 },
            "coinsurance" => { "percentage" => 20 },
            "effective_date" => "2024-01-15"
          }
        }
      )
    end

    it "includes copay amount, services covered, and effective date" do
      result = get_display_data(insurance)
      coverage = result[:coverage_details]

      expect(coverage[:copay_amount]).to eq("$25 per visit")
      expect(coverage[:services_covered]).to include("Mental health services")
      expect(coverage[:effective_date]).to eq("January 15, 2024")
      expect(coverage[:deductible]).to eq("$500 ($100 met)")
      expect(coverage[:coinsurance]).to eq(20)
    end
  end

  describe "AC3: Plain language error messages" do
    context "with INVALID_MEMBER_ID error" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "INVALID_MEMBER_ID" } }
        )
      end

      it "provides plain language explanation" do
        result = get_display_data(insurance)

        expect(result[:verification_message]).to include("member ID")
        expect(result[:why_explanation]).to include("doesn't match")
      end
    end

    context "with COVERAGE_INACTIVE error" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "COVERAGE_INACTIVE" } }
        )
      end

      it "explains the issue without jargon" do
        result = get_display_data(insurance)

        expect(result[:verification_message]).to include("isn't currently active")
      end
    end
  end

  describe "AC4: Clear next steps for all statuses" do
    context "when verified" do
      before { insurance.update!(verification_status: :verified) }

      it "provides next steps" do
        result = get_display_data(insurance)
        steps = result[:next_steps]

        expect(steps).to be_present
        expect(steps.first).to include("assessment")
      end
    end

    context "when failed" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "NETWORK_ERROR" } }
        )
      end

      it "provides next steps" do
        result = get_display_data(insurance)
        steps = result[:next_steps]

        expect(steps).to be_present
        expect(steps.any? { |s| s.downcase.include?("self-pay") }).to be true
      end
    end

    context "when pending" do
      before { insurance.update!(verification_status: :pending) }

      it "provides next steps" do
        result = get_display_data(insurance)
        steps = result[:next_steps]

        expect(steps).to be_present
      end
    end
  end

  describe "AC5: Retry option for failed verification" do
    context "when error is retriable and under attempt limit" do
      before do
        insurance.update!(
          verification_status: :failed,
          retry_attempts: 1,
          verification_result: { "error" => { "code" => "NETWORK_ERROR" } }
        )
      end

      it "shows retry is available" do
        result = get_display_data(insurance)

        expect(result[:can_retry]).to be true
        expect(result[:retry_attempts]).to eq(1)
      end
    end

    context "when retry attempts exceeded" do
      before do
        insurance.update!(
          verification_status: :failed,
          retry_attempts: 3,
          verification_result: { "error" => { "code" => "NETWORK_ERROR" } }
        )
      end

      it "shows retry is not available" do
        result = get_display_data(insurance)

        expect(result[:can_retry]).to be false
        expect(result[:retry_attempts]).to eq(3)
      end
    end
  end

  describe "AC6: Support contact for complex cases" do
    context "when error is high severity" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "COVERAGE_INACTIVE" } }
        )
      end

      it "provides specialist contact" do
        result = get_display_data(insurance)
        contact = result[:support_contact]

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

      it "provides general contact" do
        result = get_display_data(insurance)
        contact = result[:support_contact]

        expect(contact[:type]).to eq("general")
      end
    end
  end

  describe "AC7: Self-pay option always visible" do
    context "when verified" do
      before { insurance.update!(verification_status: :verified) }

      it "shows self-pay option" do
        result = get_display_data(insurance)
        self_pay = result[:self_pay_option]

        expect(self_pay[:available]).to be true
        expect(self_pay[:description]).to be_present
        expect(self_pay[:preview_rate]).to be_present
      end
    end

    context "when failed" do
      before do
        insurance.update!(
          verification_status: :failed,
          verification_result: { "error" => { "code" => "COVERAGE_INACTIVE" } }
        )
      end

      it "shows self-pay option" do
        result = get_display_data(insurance)
        self_pay = result[:self_pay_option]

        expect(self_pay[:available]).to be true
      end
    end

    context "when pending" do
      before { insurance.update!(verification_status: :pending) }

      it "shows self-pay option" do
        result = get_display_data(insurance)
        self_pay = result[:self_pay_option]

        expect(self_pay[:available]).to be true
      end
    end
  end

  describe "AC9: Parent never left without clear path forward" do
    %w[pending in_progress failed manual_review verified self_pay].each do |status|
      context "when status is #{status}" do
        before do
          insurance.update!(verification_status: status)
          if status == "failed"
            insurance.update!(verification_result: { "error" => { "code" => "NETWORK_ERROR" } })
          end
        end

        it "has next steps" do
          result = get_display_data(insurance)
          steps = result[:next_steps]

          expect(steps).to be_present
          expect(steps.length).to be >= 1
        end

        it "has self-pay option" do
          result = get_display_data(insurance)
          self_pay = result[:self_pay_option]

          expect(self_pay[:available]).to be true
        end
      end
    end
  end

  describe "Insurance model retry tracking" do
    it "tracks retry attempts" do
      insurance.update!(
        verification_status: :failed,
        verification_result: { "error" => { "code" => "NETWORK_ERROR" } }
      )

      expect(insurance.retry_attempts).to eq(0)

      insurance.increment_retry_attempts!
      expect(insurance.retry_attempts).to eq(1)

      insurance.increment_retry_attempts!
      expect(insurance.retry_attempts).to eq(2)
    end

    it "records retry history in verification_result" do
      insurance.update!(
        verification_status: :failed,
        verification_result: { "error" => { "code" => "NETWORK_ERROR" } }
      )

      insurance.increment_retry_attempts!
      insurance.reload

      history = insurance.verification_result["retry_history"]
      expect(history).to be_present
      expect(history.first["attempt"]).to eq(1)
      expect(history.first["previous_error"]).to eq("NETWORK_ERROR")
    end

    it "prevents retries after max attempts" do
      insurance.update!(
        verification_status: :failed,
        retry_attempts: 3,
        verification_result: { "error" => { "code" => "NETWORK_ERROR" } }
      )

      expect(insurance.can_retry_verification?).to be false
    end
  end
end
