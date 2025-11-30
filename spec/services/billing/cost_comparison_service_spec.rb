# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Billing::CostComparisonService, type: :service do
  let(:parent) { create(:parent) }
  let(:child) { create(:child) }
  let(:session) { create(:onboarding_session, parent: parent, child: child) }
  let!(:self_pay_rate) { create(:self_pay_rate, base_rate: 75.00) }

  subject(:service) { described_class.new(session.id) }

  describe '#call' do
    context 'when insurance is not verified' do
      before do
        session.build_insurance(verification_status: :pending)
        session.save!
      end

      it 'returns nil for insurance_estimate' do
        result = service.call
        expect(result[:insurance_estimate]).to be_nil
      end

      it 'always returns self_pay_estimate' do
        result = service.call
        expect(result[:self_pay_estimate]).to be_present
        expect(result[:self_pay_estimate][:base_rate]).to eq('$75.00 per session')
      end

      it 'returns comparison_table' do
        result = service.call
        expect(result[:comparison_table]).to be_an(Array)
        expect(result[:comparison_table]).not_to be_empty
      end

      it 'does not highlight self-pay without insurance comparison' do
        result = service.call
        expect(result[:highlight_self_pay]).to be false
      end
    end

    context 'when insurance is verified with high deductible' do
      before do
        insurance = session.build_insurance(
          verification_status: :verified,
          verification_result: {
            'coverage' => {
              'network_status' => 'in_network',
              'plan_type' => 'HDHP',
              'deductible' => { 'amount' => 2000, 'met' => 0 },
              'copay' => { 'amount' => 30 },
              'coinsurance' => { 'percentage' => 20 }
            }
          }
        )
        insurance.save!
      end

      it 'returns both estimates' do
        result = service.call
        expect(result[:insurance_estimate]).to be_present
        expect(result[:self_pay_estimate]).to be_present
      end

      it 'highlights self-pay for high deductible plans' do
        result = service.call
        expect(result[:highlight_self_pay]).to be true
      end

      it 'calculates savings when self-pay is cheaper' do
        result = service.call
        expect(result[:savings_if_self_pay]).to be_present
        expect(result[:savings_if_self_pay]).to be > 0
      end

      it 'provides recommendation to consider self-pay' do
        result = service.call
        expect(result[:recommendation]).to include('Self-pay may be more affordable')
      end
    end

    context 'when insurance is verified with low copay' do
      before do
        insurance = session.build_insurance(
          verification_status: :verified,
          verification_result: {
            'coverage' => {
              'network_status' => 'in_network',
              'plan_type' => 'HMO',
              'deductible' => { 'amount' => 500, 'met' => 500 },
              'copay' => { 'amount' => 25 },
              'coinsurance' => { 'percentage' => 0 }
            }
          }
        )
        insurance.save!
      end

      it 'does not highlight self-pay when insurance is better' do
        result = service.call
        expect(result[:highlight_self_pay]).to be false
      end

      it 'does not show savings for self-pay' do
        result = service.call
        expect(result[:savings_if_self_pay]).to be_nil
      end
    end

    context 'self-pay estimate details' do
      it 'includes transparent pricing message' do
        result = service.call
        expect(result[:self_pay_estimate][:transparent_pricing_message]).to eq('No surprise fees. Price shown is what you pay.')
      end

      it 'includes what is included' do
        result = service.call
        included = result[:self_pay_estimate][:what_is_included]
        expect(included).to include('50-minute session')
        expect(included).to include('Secure messaging between sessions')
      end

      it 'includes sliding scale info when available' do
        result = service.call
        expect(result[:self_pay_estimate][:sliding_scale_info]).to include('Sliding scale available')
      end

      it 'includes package options when available' do
        result = service.call
        packages = result[:self_pay_estimate][:package_options]
        expect(packages).to be_an(Array)
        expect(packages.first[:sessions]).to eq(4)
      end
    end

    context 'comparison table' do
      before do
        insurance = session.build_insurance(
          verification_status: :verified,
          verification_result: {
            'coverage' => {
              'network_status' => 'in_network',
              'deductible' => { 'amount' => 1500, 'met' => 0 },
              'copay' => { 'amount' => 30 }
            }
          }
        )
        insurance.save!
      end

      it 'includes per session cost row' do
        result = service.call
        row = result[:comparison_table].find { |r| r[:label] == 'Per Session Cost' }
        expect(row).to be_present
        expect(row[:self_pay_value]).to eq('$75.00')
      end

      it 'includes typical treatment row' do
        result = service.call
        row = result[:comparison_table].find { |r| r[:label].include?('Typical Treatment') }
        expect(row).to be_present
      end

      it 'highlights self-pay when it is cheaper' do
        result = service.call
        rows = result[:comparison_table]
        highlighted_rows = rows.select { |r| r[:highlight_self_pay] }
        expect(highlighted_rows).not_to be_empty
      end
    end

    context 'when no self-pay rate exists' do
      before do
        SelfPayRate.destroy_all
      end

      it 'uses default rate' do
        result = service.call
        expect(result[:self_pay_estimate][:base_rate]).to eq('$75.00 per session')
      end
    end
  end
end
