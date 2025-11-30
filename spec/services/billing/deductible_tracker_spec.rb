# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Billing::DeductibleTracker, type: :service do
  let(:onboarding_session) { create(:onboarding_session) }
  let(:insurance) { create(:insurance, :verified, onboarding_session: onboarding_session) }
  let(:tracker) { described_class.new(insurance: insurance) }

  describe '#current_status' do
    context 'with complete deductible data' do
      before do
        insurance.verification_result = {
          "verified_at" => 1.hour.ago.iso8601,
          "coverage" => {
            "deductible" => {
              "amount" => 500.0,
              "met" => 100.0,
              "remaining" => 400.0
            },
            "out_of_pocket_max" => {
              "amount" => 3000.0,
              "met" => 500.0,
              "remaining" => 2500.0
            }
          }
        }
        insurance.save!
      end

      it 'returns complete deductible status' do
        status = tracker.current_status

        expect(status[:deductible_amount]).to eq(500.0)
        expect(status[:deductible_met]).to eq(100.0)
        expect(status[:deductible_remaining]).to eq(400.0)
        expect(status[:is_met]).to be false
      end

      it 'returns OOP max tracking' do
        status = tracker.current_status

        expect(status[:oop_max_amount]).to eq(3000.0)
        expect(status[:oop_met]).to eq(500.0)
        expect(status[:oop_remaining]).to eq(2500.0)
      end

      it 'calculates progress percentages' do
        status = tracker.current_status

        expect(status[:progress_percentage]).to eq(20) # 100/500 * 100
        expect(status[:oop_progress_percentage]).to eq(17) # 500/3000 * 100 rounded
      end

      it 'provides data source information' do
        status = tracker.current_status

        expect(status[:data_source]).to eq('eligibility_api')
        expect(status[:last_updated_at]).to be_within(2.minutes).of(1.hour.ago)
      end
    end

    context 'with family plan' do
      before do
        insurance.verification_result = {
          "coverage" => {
            "family_deductible" => {
              "amount" => 1000.0,
              "met" => 300.0
            },
            "family_out_of_pocket_max" => {
              "amount" => 5000.0,
              "met" => 800.0
            }
          }
        }
        insurance.save!
      end

      it 'detects family plan' do
        status = tracker.current_status
        expect(status[:is_family_plan]).to be true
      end

      it 'uses family deductible amounts' do
        status = tracker.current_status

        expect(status[:deductible_amount]).to eq(1000.0)
        expect(status[:deductible_met]).to eq(300.0)
        expect(status[:deductible_remaining]).to eq(700.0)
      end

      it 'uses family OOP max amounts' do
        status = tracker.current_status

        expect(status[:oop_max_amount]).to eq(5000.0)
        expect(status[:oop_met]).to eq(800.0)
      end
    end

    context 'with manual override' do
      before do
        insurance.verification_result = {
          "coverage" => {
            "deductible" => {
              "amount" => 500.0,
              "met" => 100.0
            }
          },
          "deductible_override" => {
            "deductible_met" => 250.0,
            "oop_met" => 400.0,
            "override_timestamp" => 30.minutes.ago.iso8601,
            "override_by" => "admin_user",
            "override_reason" => "Patient provided EOB",
            "source" => "manual"
          }
        }
        insurance.save!
      end

      it 'prioritizes override values' do
        status = tracker.current_status

        expect(status[:deductible_met]).to eq(250.0)
        expect(status[:deductible_remaining]).to eq(250.0) # 500 - 250
      end

      it 'indicates manual override as data source' do
        status = tracker.current_status
        expect(status[:data_source]).to eq('manual_override')
      end

      it 'uses override timestamp' do
        status = tracker.current_status
        expect(status[:last_updated_at]).to be_within(1.minute).of(30.minutes.ago)
      end
    end

    context 'with missing data' do
      before do
        insurance.verification_result = { "coverage" => {} }
        insurance.save!
      end

      it 'returns nil for missing fields' do
        status = tracker.current_status

        expect(status[:deductible_amount]).to be_nil
        expect(status[:oop_max_amount]).to be_nil
      end

      it 'returns zero for backward compatible fields' do
        status = tracker.current_status

        expect(status[:amount]).to eq(0.0)
        expect(status[:met]).to eq(0.0)
        expect(status[:remaining]).to eq(0.0)
      end

      it 'returns false for is_family_plan' do
        status = tracker.current_status
        expect(status[:is_family_plan]).to be false
      end
    end
  end

  describe '#sessions_until_deductible_met' do
    before do
      # Set up session rates configuration
      Rails.application.config.session_rates = {
        "individual_therapy" => 100.0
      }
      Rails.application.config.default_session_type = "individual_therapy"
    end

    context 'with deductible partially met' do
      it 'calculates sessions needed' do
        expect(tracker.sessions_until_deductible_met(300.0)).to eq(3) # 300 / 100 = 3
      end

      it 'rounds up partial sessions' do
        expect(tracker.sessions_until_deductible_met(250.0)).to eq(3) # 250 / 100 = 2.5, rounded up to 3
      end
    end

    context 'with deductible fully met' do
      it 'returns zero' do
        expect(tracker.sessions_until_deductible_met(0.0)).to eq(0)
      end

      it 'returns zero for negative remaining' do
        expect(tracker.sessions_until_deductible_met(-50.0)).to eq(0)
      end
    end

    context 'with no session rate available' do
      before do
        Rails.application.config.session_rates = {}
      end

      it 'uses fallback rate' do
        expect(tracker.sessions_until_deductible_met(300.0)).to eq(3) # Uses 100.0 fallback
      end
    end
  end

  describe 'progress percentage integration' do
    before do
      insurance.verification_result = {
        "coverage" => {
          "deductible" => {
            "amount" => 500.0,
            "met" => 100.0
          }
        }
      }
      insurance.save!
    end

    it 'calculates percentage correctly in current_status' do
      status = tracker.current_status
      expect(status[:progress_percentage]).to eq(20) # 100/500 * 100
    end

    context 'when deductible is fully met' do
      before do
        insurance.verification_result["coverage"]["deductible"]["met"] = 500.0
        insurance.save!
      end

      it 'returns 100%' do
        status = tracker.current_status
        expect(status[:progress_percentage]).to eq(100)
      end
    end

    context 'when deductible amount is zero' do
      before do
        insurance.verification_result["coverage"]["deductible"]["amount"] = 0.0
        insurance.save!
      end

      it 'returns 0%' do
        status = tracker.current_status
        expect(status[:progress_percentage]).to eq(0)
      end
    end
  end

  describe 'plan year reset date' do
    context 'with plan year start in verification result' do
      before do
        insurance.verification_result = {
          "coverage" => {
            "plan_year_start" => "2025-07-01"
          }
        }
        insurance.save!
      end

      it 'includes reset date in status' do
        travel_to Date.new(2025, 11, 30) do
          status = tracker.current_status
          expect(status[:year_reset_date]).to eq(Date.new(2026, 7, 1))
        end
      end
    end

    context 'without plan year start' do
      before do
        insurance.verification_result = { "coverage" => {} }
        insurance.save!
      end

      it 'defaults to next January 1' do
        travel_to Date.new(2025, 11, 30) do
          status = tracker.current_status
          expect(status[:year_reset_date]).to eq(Date.new(2026, 1, 1))
        end
      end
    end
  end
end
