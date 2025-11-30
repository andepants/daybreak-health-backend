# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Billing::InsuranceEstimateService, type: :service do
  let(:onboarding_session) { create(:onboarding_session) }
  let(:insurance) { create(:insurance, onboarding_session: onboarding_session) }
  let(:service_type) { 'individual_therapy' }

  # Create a session rate for testing
  let!(:session_rate) do
    SessionRate.create!(
      service_type: service_type,
      base_rate: BigDecimal('150.00'),
      effective_date: 30.days.ago,
      end_date: nil
    )
  end

  describe '.call' do
    context 'when insurance is not verified' do
      before do
        insurance.update_column(:verification_status, Insurance.verification_statuses[:pending])
      end

      it 'raises ArgumentError' do
        expect {
          described_class.call(insurance: insurance, service_type: service_type)
        }.to raise_error(ArgumentError, /must be verified/)
      end
    end

    context 'when verification_result is missing' do
      before do
        insurance.update_columns(
          verification_status: Insurance.verification_statuses[:verified],
          verification_result: nil
        )
      end

      it 'raises ArgumentError' do
        expect {
          described_class.call(insurance: insurance, service_type: service_type)
        }.to raise_error(ArgumentError, /verification_result is missing/)
      end
    end

    context 'when coverage data is incomplete' do
      before do
        insurance.update_columns(
          verification_status: Insurance.verification_statuses[:verified],
          verification_result: { "verified_at" => Time.current.iso8601 }
        )
      end

      it 'raises ArgumentError' do
        expect {
          described_class.call(insurance: insurance, service_type: service_type)
        }.to raise_error(ArgumentError, /coverage data is incomplete/)
      end
    end

    context 'with verified insurance and complete coverage data' do
      let(:coverage_data) do
        {
          "eligible" => true,
          "coverage" => {
            "mental_health_covered" => true,
            "copay" => { "amount" => 25.0 },
            "deductible" => { "amount" => 500.0, "met" => 0.0 },
            "coinsurance" => { "percentage" => 20 },
            "effective_date" => 90.days.ago.to_date.iso8601,
            "network_status" => "in_network"
          },
          "verified_at" => Time.current.iso8601
        }
      end

      before do
        insurance.update_columns(
          verification_status: Insurance.verification_statuses[:verified],
          verification_result: coverage_data
        )
      end

      it 'returns a cost estimate hash' do
        result = described_class.call(insurance: insurance, service_type: service_type)

        expect(result).to be_a(Hash)
        expect(result).to have_key(:insurance_pays)
        expect(result).to have_key(:patient_pays)
        expect(result).to have_key(:allowed_amount)
        expect(result).to have_key(:billed_amount)
        expect(result).to have_key(:deductible_status)
        expect(result).to have_key(:coverage_limitations)
        expect(result).to have_key(:is_estimate)
        expect(result).to have_key(:disclaimer)
        expect(result).to have_key(:calculated_at)
      end

      it 'sets is_estimate to true' do
        result = described_class.call(insurance: insurance, service_type: service_type)
        expect(result[:is_estimate]).to be true
      end

      it 'includes disclaimer text' do
        result = described_class.call(insurance: insurance, service_type: service_type)
        expect(result[:disclaimer]).to include("estimate only")
        expect(result[:disclaimer]).to include("not a guarantee")
      end

      it 'returns BigDecimal amounts' do
        result = described_class.call(insurance: insurance, service_type: service_type)
        expect(result[:insurance_pays]).to be_a(BigDecimal)
        expect(result[:patient_pays]).to be_a(BigDecimal)
        expect(result[:allowed_amount]).to be_a(BigDecimal)
        expect(result[:billed_amount]).to be_a(BigDecimal)
      end
    end

    context 'HMO plan with copay' do
      let(:hmo_coverage) do
        {
          "eligible" => true,
          "coverage" => {
            "mental_health_covered" => true,
            "copay" => { "amount" => 25.0 },
            "deductible" => { "amount" => 0, "met" => 0 },
            "effective_date" => 90.days.ago.to_date.iso8601,
            "network_status" => "in_network",
            "plan_type" => "HMO"
          },
          "verified_at" => Time.current.iso8601
        }
      end

      before do
        insurance.update_columns(
          verification_status: Insurance.verification_statuses[:verified],
          verification_result: hmo_coverage
        )
      end

      it 'calculates patient pays as copay amount' do
        result = described_class.call(insurance: insurance, service_type: service_type)

        allowed_amount = BigDecimal('150.00') * BigDecimal('0.85') # 85% of billed
        expected_patient_pays = BigDecimal('25.00')
        expected_insurance_pays = allowed_amount - expected_patient_pays

        expect(result[:patient_pays]).to eq(expected_patient_pays)
        expect(result[:insurance_pays]).to eq(expected_insurance_pays)
      end
    end

    context 'PPO plan with deductible not met' do
      let(:ppo_coverage) do
        {
          "eligible" => true,
          "coverage" => {
            "mental_health_covered" => true,
            "copay" => { "amount" => 0 },
            "deductible" => { "amount" => 1000.0, "met" => 0.0 },
            "coinsurance" => { "percentage" => 20 },
            "effective_date" => 90.days.ago.to_date.iso8601,
            "network_status" => "in_network",
            "plan_type" => "PPO"
          },
          "verified_at" => Time.current.iso8601
        }
      end

      before do
        insurance.update_columns(
          verification_status: Insurance.verification_statuses[:verified],
          verification_result: ppo_coverage
        )
      end

      it 'patient pays full allowed amount toward deductible' do
        result = described_class.call(insurance: insurance, service_type: service_type)

        allowed_amount = BigDecimal('150.00') * BigDecimal('0.85')
        expected_patient_pays = allowed_amount
        expected_insurance_pays = BigDecimal('0')

        expect(result[:patient_pays]).to eq(expected_patient_pays)
        expect(result[:insurance_pays]).to eq(expected_insurance_pays)
        expect(result[:deductible_status][:is_met]).to be false
        expect(result[:deductible_status][:remaining]).to eq(BigDecimal('1000.00'))
      end
    end

    context 'PPO plan with deductible met and coinsurance' do
      let(:ppo_met_coverage) do
        {
          "eligible" => true,
          "coverage" => {
            "mental_health_covered" => true,
            "copay" => { "amount" => 0 },
            "deductible" => { "amount" => 1000.0, "met" => 1000.0 },
            "coinsurance" => { "percentage" => 20 },
            "effective_date" => 90.days.ago.to_date.iso8601,
            "network_status" => "in_network",
            "plan_type" => "PPO"
          },
          "verified_at" => Time.current.iso8601
        }
      end

      before do
        insurance.update_columns(
          verification_status: Insurance.verification_statuses[:verified],
          verification_result: ppo_met_coverage
        )
      end

      it 'patient pays coinsurance percentage' do
        result = described_class.call(insurance: insurance, service_type: service_type)

        allowed_amount = BigDecimal('150.00') * BigDecimal('0.85')
        expected_patient_pays = allowed_amount * BigDecimal('0.20')
        expected_insurance_pays = allowed_amount - expected_patient_pays

        expect(result[:patient_pays]).to eq(expected_patient_pays.round(2))
        expect(result[:insurance_pays]).to eq(expected_insurance_pays.round(2))
        expect(result[:deductible_status][:is_met]).to be true
      end
    end

    context 'High-deductible plan with deductible not met' do
      let(:hdhp_coverage) do
        {
          "eligible" => true,
          "coverage" => {
            "mental_health_covered" => true,
            "copay" => { "amount" => 0 },
            "deductible" => { "amount" => 3000.0, "met" => 500.0 },
            "coinsurance" => { "percentage" => 20 },
            "effective_date" => 90.days.ago.to_date.iso8601,
            "network_status" => "in_network",
            "plan_type" => "HDHP"
          },
          "verified_at" => Time.current.iso8601
        }
      end

      before do
        insurance.update_columns(
          verification_status: Insurance.verification_statuses[:verified],
          verification_result: hdhp_coverage
        )
      end

      it 'patient pays toward deductible remaining' do
        result = described_class.call(insurance: insurance, service_type: service_type)

        allowed_amount = BigDecimal('150.00') * BigDecimal('0.85')
        deductible_remaining = BigDecimal('2500.00')
        expected_patient_pays = allowed_amount # Less than remaining deductible
        expected_insurance_pays = BigDecimal('0')

        expect(result[:patient_pays]).to eq(expected_patient_pays)
        expect(result[:insurance_pays]).to eq(expected_insurance_pays)
        expect(result[:deductible_status][:remaining]).to eq(deductible_remaining)
      end
    end

    context 'with session limit coverage limitation' do
      let(:limited_coverage) do
        {
          "eligible" => true,
          "coverage" => {
            "mental_health_covered" => true,
            "copay" => { "amount" => 25.0 },
            "deductible" => { "amount" => 500.0, "met" => 500.0 },
            "effective_date" => 90.days.ago.to_date.iso8601,
            "network_status" => "in_network",
            "session_limit" => 20,
            "sessions_used" => 15
          },
          "verified_at" => Time.current.iso8601
        }
      end

      before do
        insurance.update_columns(
          verification_status: Insurance.verification_statuses[:verified],
          verification_result: limited_coverage
        )
      end

      it 'includes session limit in coverage limitations' do
        result = described_class.call(insurance: insurance, service_type: service_type)

        expect(result[:coverage_limitations]).to be_an(Array)
        expect(result[:coverage_limitations].any? { |msg| msg.include?("5 sessions remaining") }).to be true
      end
    end

    context 'with prior authorization requirement' do
      let(:prior_auth_coverage) do
        {
          "eligible" => true,
          "coverage" => {
            "mental_health_covered" => true,
            "copay" => { "amount" => 25.0 },
            "deductible" => { "amount" => 500.0, "met" => 500.0 },
            "effective_date" => 90.days.ago.to_date.iso8601,
            "network_status" => "in_network",
            "requires_prior_authorization" => true
          },
          "verified_at" => Time.current.iso8601
        }
      end

      before do
        insurance.update_columns(
          verification_status: Insurance.verification_statuses[:verified],
          verification_result: prior_auth_coverage
        )
      end

      it 'includes prior auth requirement in coverage limitations' do
        result = described_class.call(insurance: insurance, service_type: service_type)

        expect(result[:coverage_limitations]).to be_an(Array)
        expect(result[:coverage_limitations].any? { |msg| msg.include?("Prior authorization") }).to be true
      end
    end

    context 'with out-of-network status' do
      let(:oon_coverage) do
        {
          "eligible" => true,
          "coverage" => {
            "mental_health_covered" => true,
            "copay" => { "amount" => 25.0 },
            "deductible" => { "amount" => 500.0, "met" => 500.0 },
            "effective_date" => 90.days.ago.to_date.iso8601,
            "network_status" => "out_of_network"
          },
          "verified_at" => Time.current.iso8601
        }
      end

      before do
        insurance.update_columns(
          verification_status: Insurance.verification_statuses[:verified],
          verification_result: oon_coverage
        )
      end

      it 'includes out-of-network warning in coverage limitations' do
        result = described_class.call(insurance: insurance, service_type: service_type)

        expect(result[:coverage_limitations]).to be_an(Array)
        expect(result[:coverage_limitations].any? { |msg| msg.include?("out-of-network") }).to be true
      end

      it 'uses billed amount as allowed amount for out-of-network' do
        result = described_class.call(insurance: insurance, service_type: service_type)

        expect(result[:allowed_amount]).to eq(BigDecimal('150.00'))
      end
    end

    context 'with coverage termination date approaching' do
      let(:terminating_coverage) do
        {
          "eligible" => true,
          "coverage" => {
            "mental_health_covered" => true,
            "copay" => { "amount" => 25.0 },
            "deductible" => { "amount" => 500.0, "met" => 500.0 },
            "effective_date" => 90.days.ago.to_date.iso8601,
            "network_status" => "in_network",
            "termination_date" => 15.days.from_now.to_date.iso8601
          },
          "verified_at" => Time.current.iso8601
        }
      end

      before do
        insurance.update_columns(
          verification_status: Insurance.verification_statuses[:verified],
          verification_result: terminating_coverage
        )
      end

      it 'includes termination warning in coverage limitations' do
        result = described_class.call(insurance: insurance, service_type: service_type)

        expect(result[:coverage_limitations]).to be_an(Array)
        expect(result[:coverage_limitations].any? { |msg| msg.include?("coverage ends") }).to be true
      end
    end

    context 'caching behavior' do
      let(:coverage_data) do
        {
          "eligible" => true,
          "coverage" => {
            "mental_health_covered" => true,
            "copay" => { "amount" => 25.0 },
            "deductible" => { "amount" => 500.0, "met" => 0.0 },
            "effective_date" => 90.days.ago.to_date.iso8601,
            "network_status" => "in_network"
          },
          "verified_at" => Time.current.iso8601
        }
      end

      before do
        insurance.update_columns(
          verification_status: Insurance.verification_statuses[:verified],
          verification_result: coverage_data
        )
        Rails.cache.clear
      end

      it 'caches the estimate result' do
        # First call should calculate
        result1 = described_class.call(insurance: insurance, service_type: service_type)

        # Second call should return cached value (same values, though timestamp may differ by a second)
        expect(Rails.cache).to receive(:read).and_call_original
        result2 = described_class.call(insurance: insurance, service_type: service_type)

        # Compare all fields except calculated_at (which may differ by a second)
        expect(result1[:insurance_pays]).to eq(result2[:insurance_pays])
        expect(result1[:patient_pays]).to eq(result2[:patient_pays])
        expect(result1[:allowed_amount]).to eq(result2[:allowed_amount])
        expect(result1[:is_estimate]).to eq(result2[:is_estimate])
      end

      it 'cache key includes insurance id, verified_at, deductible_met, service_type, and coverage hash' do
        # Verify that cache write is called with correct key pattern
        # Cache key format: insurance:estimate:{id}:{verified_at}:{deductible_met}:{service_type}:{coverage_hash}
        expect(Rails.cache).to receive(:write).with(
          a_string_matching(/insurance:estimate:#{insurance.id}:\d+:[\d.]+:#{service_type}:[a-f0-9]{16}/),
          anything,
          anything
        ).and_call_original

        described_class.call(insurance: insurance, service_type: service_type)
      end

      it 'cache expires after 24 hours' do
        allow(Rails.cache).to receive(:write).and_call_original

        described_class.call(insurance: insurance, service_type: service_type)

        expect(Rails.cache).to have_received(:write).with(
          anything,
          anything,
          hash_including(expires_in: 24.hours)
        )
      end
    end
  end
end
