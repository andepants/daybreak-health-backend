# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Billing::CostCalculationService, type: :service do
  let!(:individual_rate) { create(:session_rate, service_type: 'individual_therapy', base_rate: 150.00) }
  let!(:family_rate) { create(:session_rate, service_type: 'family_therapy', base_rate: 200.00) }

  describe '#call' do
    context 'with basic parameters' do
      it 'calculates cost for standard individual therapy session' do
        result = described_class.call(service_type: 'individual_therapy')

        expect(result[:gross_cost]).to eq(150.00)
        expect(result[:net_cost]).to eq(150.00)
        expect(result[:adjustments]).to be_empty
        expect(result[:currency]).to eq('USD')
        expect(result[:calculated_at]).to be_present
      end

      it 'calculates cost for family therapy' do
        result = described_class.call(service_type: 'family_therapy')

        expect(result[:gross_cost]).to eq(200.00)
        expect(result[:net_cost]).to eq(200.00)
      end
    end

    context 'with duration modifier' do
      it 'applies duration modifier for longer session' do
        result = described_class.call(
          service_type: 'individual_therapy',
          duration: 90
        )

        expect(result[:gross_cost]).to eq(150.00)
        # 90 minutes / 50 minutes = 1.8x = 150 * 1.8 = 270
        expect(result[:net_cost]).to eq(270.00)

        adjustment = result[:adjustments].find { |a| a[:type] == 'duration_modifier' }
        expect(adjustment).to be_present
        expect(adjustment[:amount]).to eq(120.00) # 150 * 0.8
        expect(adjustment[:percentage]).to eq(80.0)
      end

      it 'applies duration modifier for shorter session' do
        result = described_class.call(
          service_type: 'individual_therapy',
          duration: 25
        )

        # 25 minutes / 50 minutes = 0.5x = 150 * 0.5 = 75
        expect(result[:net_cost]).to eq(75.00)

        adjustment = result[:adjustments].find { |a| a[:type] == 'duration_modifier' }
        expect(adjustment[:amount]).to eq(-75.00) # 150 * -0.5
        expect(adjustment[:percentage]).to eq(-50.0)
      end
    end

    context 'with therapist tier modifier' do
      it 'applies senior therapist tier modifier' do
        result = described_class.call(
          service_type: 'individual_therapy',
          therapist_tier: 'senior'
        )

        # Base: 150, Senior: 1.2x = 30
        expect(result[:net_cost]).to eq(180.00)

        adjustment = result[:adjustments].find { |a| a[:type] == 'therapist_tier' }
        expect(adjustment).to be_present
        expect(adjustment[:amount]).to eq(30.00)
        expect(adjustment[:percentage]).to eq(20.0)
      end

      it 'applies specialist tier modifier' do
        result = described_class.call(
          service_type: 'individual_therapy',
          therapist_tier: 'specialist'
        )

        # Base: 150, Specialist: 1.5x = 75
        expect(result[:net_cost]).to eq(225.00)
      end
    end

    context 'with special services' do
      it 'applies special service fees' do
        result = described_class.call(
          service_type: 'individual_therapy',
          special_services: ['telehealth_setup', 'translation']
        )

        # Base: 150 + telehealth: 10 + translation: 25 = 185
        expect(result[:net_cost]).to eq(185.00)

        telehealth_adj = result[:adjustments].find { |a| a[:description].include?('Telehealth Setup') }
        expect(telehealth_adj[:amount]).to eq(10.00)

        translation_adj = result[:adjustments].find { |a| a[:description].include?('Translation') }
        expect(translation_adj[:amount]).to eq(25.00)
      end
    end

    context 'with tax' do
      it 'applies tax calculation' do
        result = described_class.call(
          service_type: 'individual_therapy',
          tax_rate: 0.075
        )

        # Base: 150, Tax: 11.25 = 161.25
        expect(result[:net_cost]).to eq(161.25)

        tax_adj = result[:adjustments].find { |a| a[:type] == 'tax' }
        expect(tax_adj[:amount]).to eq(11.25)
        expect(tax_adj[:percentage]).to eq(7.5)
      end
    end

    context 'with discount codes' do
      it 'applies percentage discount' do
        result = described_class.call(
          service_type: 'individual_therapy',
          discount_code: 'PERCENTAGE_10'
        )

        # Base: 150, Discount: -15 = 135
        expect(result[:net_cost]).to eq(135.00)

        discount_adj = result[:adjustments].find { |a| a[:type] == 'discount' }
        expect(discount_adj[:amount]).to eq(-15.00)
      end

      it 'applies fixed amount discount' do
        result = described_class.call(
          service_type: 'individual_therapy',
          discount_code: 'FIXED_25'
        )

        # Base: 150, Discount: -25 = 125
        expect(result[:net_cost]).to eq(125.00)

        discount_adj = result[:adjustments].find { |a| a[:type] == 'discount' }
        expect(discount_adj[:amount]).to eq(-25.00)
      end

      it 'applies hardship discount' do
        result = described_class.call(
          service_type: 'individual_therapy',
          discount_code: 'HARDSHIP_50'
        )

        # Base: 150, Hardship: -75 = 75
        expect(result[:net_cost]).to eq(75.00)
      end

      it 'ignores invalid discount code' do
        result = described_class.call(
          service_type: 'individual_therapy',
          discount_code: 'INVALID_CODE'
        )

        expect(result[:net_cost]).to eq(150.00)
        expect(result[:adjustments]).to be_empty
      end
    end

    context 'with combined modifiers' do
      it 'calculates correctly with all modifiers' do
        result = described_class.call(
          service_type: 'family_therapy',
          duration: 90,
          therapist_tier: 'senior',
          special_services: ['translation'],
          tax_rate: 0.075,
          discount_code: 'PERCENTAGE_10'
        )

        # Base: 200
        # Duration: 90/50 = 1.8x = +160
        # Therapist: 1.2x on base = +40
        # Translation: +25
        # Subtotal: 425
        # Tax: 425 * 0.075 = +31.875
        # Subtotal with tax: 456.875
        # Discount: 10% of 456.875 = -45.6875
        # Final: 411.1875 -> 411.19

        expect(result[:net_cost]).to eq(411.19)
        expect(result[:adjustments].length).to eq(5)
      end
    end

    context 'with edge cases' do
      it 'ensures net cost never goes negative' do
        result = described_class.call(
          service_type: 'individual_therapy',
          discount_code: 'FIXED_200'
        )

        expect(result[:net_cost]).to eq(0.00)
      end

      it 'is deterministic (same inputs produce same output)' do
        params = {
          service_type: 'individual_therapy',
          duration: 75,
          therapist_tier: 'lead',
          discount_code: 'PERCENTAGE_15'
        }

        result1 = described_class.call(**params)
        result2 = described_class.call(**params)

        expect(result1[:net_cost]).to eq(result2[:net_cost])
        expect(result1[:gross_cost]).to eq(result2[:gross_cost])
      end
    end

    context 'with validation errors' do
      it 'raises error for invalid service type' do
        expect {
          described_class.call(service_type: 'invalid_type')
        }.to raise_error(ArgumentError, /Invalid service_type/)
      end

      it 'raises error for invalid duration' do
        expect {
          described_class.call(service_type: 'individual_therapy', duration: -10)
        }.to raise_error(ArgumentError, /Duration must be positive/)
      end

      it 'raises error for invalid therapist tier' do
        expect {
          described_class.call(service_type: 'individual_therapy', therapist_tier: 'invalid')
        }.to raise_error(ArgumentError, /Invalid therapist_tier/)
      end

      it 'raises error when rate not found' do
        expect {
          described_class.call(service_type: 'intake')
        }.to raise_error(ArgumentError, /No rate found/)
      end
    end

    context 'with metadata' do
      it 'includes calculation metadata' do
        result = described_class.call(
          service_type: 'individual_therapy',
          duration: 60
        )

        expect(result[:metadata][:service_type]).to eq('individual_therapy')
        expect(result[:metadata][:duration]).to eq(60)
        expect(result[:metadata][:therapist_tier]).to eq('standard')
        expect(result[:metadata][:date]).to be_present
      end
    end
  end
end
