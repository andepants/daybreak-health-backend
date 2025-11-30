# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Billing::PaymentPlanService, type: :service do
  describe '.call' do
    subject(:plans) { described_class.call(total_amount: total_amount, options: options) }

    let(:total_amount) { 1200.00 }
    let(:options) { {} }

    context 'with valid total amount' do
      it 'returns array of payment plan options' do
        expect(plans).to be_an(Array)
        expect(plans.length).to eq(4) # 1 upfront + 3 monthly plans
      end

      it 'includes upfront payment option as first plan' do
        upfront_plan = plans.first
        expect(upfront_plan[:duration_months]).to eq(0)
        expect(upfront_plan[:upfront_discount]).to eq(5.0)
      end

      it 'includes 3, 6, and 12 month payment plans' do
        monthly_plans = plans[1..]
        durations = monthly_plans.map { |p| p[:duration_months] }
        expect(durations).to contain_exactly(3, 6, 12)
      end

      it 'returns plans with required fields' do
        plans.each do |plan|
          expect(plan).to include(
            :duration_months,
            :monthly_amount,
            :total_amount,
            :interest_rate,
            :has_fees,
            :fee_amount,
            :description
          )
        end
      end
    end

    context 'upfront payment option' do
      let(:total_amount) { 1000.00 }

      it 'applies 5% discount by default' do
        upfront_plan = plans.first
        expect(upfront_plan[:total_amount]).to eq(BigDecimal("950.00"))
        expect(upfront_plan[:upfront_discount]).to eq(5.0)
      end

      it 'has monthly_amount equal to total_amount' do
        upfront_plan = plans.first
        expect(upfront_plan[:monthly_amount]).to eq(upfront_plan[:total_amount])
      end

      it 'has no interest or fees' do
        upfront_plan = plans.first
        expect(upfront_plan[:interest_rate]).to eq(0.0)
        expect(upfront_plan[:has_fees]).to be false
        expect(upfront_plan[:fee_amount]).to eq(0.0)
      end

      it 'has descriptive text' do
        upfront_plan = plans.first
        expect(upfront_plan[:description]).to include("Pay in full")
        expect(upfront_plan[:description]).to include("5.0% discount")
      end
    end

    context 'monthly payment plans' do
      let(:total_amount) { 300.00 }

      it 'calculates correct monthly amount for 3-month plan' do
        plan_3_month = plans.find { |p| p[:duration_months] == 3 }
        expect(plan_3_month[:monthly_amount]).to eq(BigDecimal("100.00"))
        expect(plan_3_month[:total_amount]).to eq(BigDecimal("300.00"))
      end

      it 'calculates correct monthly amount for 6-month plan' do
        plan_6_month = plans.find { |p| p[:duration_months] == 6 }
        expect(plan_6_month[:monthly_amount]).to eq(BigDecimal("50.00"))
        expect(plan_6_month[:total_amount]).to eq(BigDecimal("300.00"))
      end

      it 'calculates correct monthly amount for 12-month plan' do
        plan_12_month = plans.find { |p| p[:duration_months] == 12 }
        expect(plan_12_month[:monthly_amount]).to eq(BigDecimal("25.00"))
        expect(plan_12_month[:total_amount]).to eq(BigDecimal("300.00"))
      end

      it 'has 0% interest rate for MVP' do
        monthly_plans = plans[1..]
        monthly_plans.each do |plan|
          expect(plan[:interest_rate]).to eq(0.0)
        end
      end

      it 'has no fees for MVP' do
        monthly_plans = plans[1..]
        monthly_plans.each do |plan|
          expect(plan[:has_fees]).to be false
          expect(plan[:fee_amount]).to eq(0.0)
        end
      end

      it 'has descriptive text with duration and monthly amount' do
        plan_3_month = plans.find { |p| p[:duration_months] == 3 }
        expect(plan_3_month[:description]).to include("3 monthly payments")
      end
    end

    context 'with rounding edge cases' do
      let(:total_amount) { 100.00 }

      it 'rounds monthly payments correctly for 3-month plan' do
        plan_3_month = plans.find { |p| p[:duration_months] == 3 }
        # 100 / 3 = 33.333... should round to 33.33
        expect(plan_3_month[:monthly_amount]).to eq(BigDecimal("33.33"))
      end

      it 'maintains total cost accuracy despite rounding' do
        monthly_plans = plans[1..]
        monthly_plans.each do |plan|
          # Total should always equal original amount (no interest/fees for MVP)
          expect(plan[:total_amount]).to eq(BigDecimal("100.00"))
        end
      end
    end

    context 'with custom options' do
      context 'custom durations' do
        let(:options) { { durations: [1, 2, 4] } }

        it 'uses custom durations' do
          monthly_plans = plans[1..]
          durations = monthly_plans.map { |p| p[:duration_months] }
          expect(durations).to contain_exactly(1, 2, 4)
        end
      end

      context 'custom upfront discount' do
        let(:total_amount) { 1000.00 }
        let(:options) { { upfront_discount: 10.0 } }

        it 'applies custom upfront discount' do
          upfront_plan = plans.first
          expect(upfront_plan[:total_amount]).to eq(BigDecimal("900.00"))
          expect(upfront_plan[:upfront_discount]).to eq(10.0)
        end
      end

      context 'custom interest rates' do
        let(:total_amount) { 1200.00 }
        let(:options) { { interest_rates: { 3 => 5.0, 6 => 3.0, 12 => 2.0 } } }

        it 'applies interest to 3-month plan' do
          plan_3_month = plans.find { |p| p[:duration_months] == 3 }
          # Interest: 1200 * 0.05 * (3/12) = 15
          # Total: 1200 + 15 = 1215
          expect(plan_3_month[:total_amount]).to eq(BigDecimal("1215.00"))
          expect(plan_3_month[:interest_rate]).to eq(5.0)
          expect(plan_3_month[:has_fees]).to be true
          expect(plan_3_month[:fee_amount]).to eq(BigDecimal("15.00"))
        end

        it 'applies interest to 6-month plan' do
          plan_6_month = plans.find { |p| p[:duration_months] == 6 }
          # Interest: 1200 * 0.03 * (6/12) = 18
          # Total: 1200 + 18 = 1218
          expect(plan_6_month[:total_amount]).to eq(BigDecimal("1218.00"))
          expect(plan_6_month[:interest_rate]).to eq(3.0)
        end

        it 'applies interest to 12-month plan' do
          plan_12_month = plans.find { |p| p[:duration_months] == 12 }
          # Interest: 1200 * 0.02 * (12/12) = 24
          # Total: 1200 + 24 = 1224
          expect(plan_12_month[:total_amount]).to eq(BigDecimal("1224.00"))
          expect(plan_12_month[:interest_rate]).to eq(2.0)
        end
      end

      context 'custom service fees' do
        let(:total_amount) { 1000.00 }
        let(:options) { { service_fees: { 3 => 10.0, 6 => 15.0, 12 => 20.0 } } }

        it 'applies service fee to 3-month plan' do
          plan_3_month = plans.find { |p| p[:duration_months] == 3 }
          expect(plan_3_month[:total_amount]).to eq(BigDecimal("1010.00"))
          expect(plan_3_month[:has_fees]).to be true
          expect(plan_3_month[:fee_amount]).to eq(BigDecimal("10.00"))
        end
      end
    end

    context 'with edge case amounts' do
      context 'with very small amount' do
        let(:total_amount) { 1.00 }

        it 'handles very small amounts' do
          expect(plans).to be_an(Array)
          expect(plans.length).to eq(4)
        end

        it 'maintains positive amounts' do
          plans.each do |plan|
            expect(plan[:total_amount]).to be > 0
            expect(plan[:monthly_amount]).to be > 0
          end
        end
      end

      context 'with very large amount' do
        let(:total_amount) { 999_999.99 }

        it 'handles very large amounts' do
          expect(plans).to be_an(Array)
          expect(plans.length).to eq(4)
        end

        it 'maintains precision for large amounts' do
          plan_12_month = plans.find { |p| p[:duration_months] == 12 }
          monthly = plan_12_month[:monthly_amount]
          # 999999.99 / 12 = 83333.3325 -> 83333.33
          expect(monthly).to eq(BigDecimal("83333.33"))
        end
      end

      context 'with zero amount' do
        let(:total_amount) { 0 }

        it 'raises ArgumentError' do
          expect { plans }.to raise_error(ArgumentError, /Total amount must be positive/)
        end
      end

      context 'with negative amount' do
        let(:total_amount) { -100 }

        it 'raises ArgumentError' do
          expect { plans }.to raise_error(ArgumentError, /Total amount must be positive/)
        end
      end
    end

    context 'with invalid options' do
      context 'invalid durations' do
        let(:options) { { durations: [0, -1, 3] } }

        it 'raises ArgumentError for invalid duration' do
          expect { plans }.to raise_error(ArgumentError, /Invalid duration/)
        end
      end

      context 'invalid upfront discount' do
        let(:options) { { upfront_discount: 150 } }

        it 'raises ArgumentError for discount > 100%' do
          expect { plans }.to raise_error(ArgumentError, /Upfront discount must be between 0 and 100/)
        end
      end

      context 'negative upfront discount' do
        let(:options) { { upfront_discount: -5 } }

        it 'raises ArgumentError for negative discount' do
          expect { plans }.to raise_error(ArgumentError, /Upfront discount must be between 0 and 100/)
        end
      end
    end

    context 'with configuration loaded from config' do
      before do
        allow(Rails.application.config).to receive(:respond_to?).and_return(true)
        allow(Rails.application.config).to receive(:payment_plans).and_return({
          plan_durations: [2, 4, 8],
          upfront_discount_percentage: 7.5,
          interest_rates: { 2 => 0, 4 => 0, 8 => 0 },
          service_fees: { 2 => 0, 4 => 0, 8 => 0 }
        })
      end

      it 'uses configured plan durations' do
        monthly_plans = plans[1..]
        durations = monthly_plans.map { |p| p[:duration_months] }
        expect(durations).to contain_exactly(2, 4, 8)
      end

      it 'uses configured upfront discount' do
        upfront_plan = plans.first
        expect(upfront_plan[:upfront_discount]).to eq(7.5)
      end
    end
  end
end
