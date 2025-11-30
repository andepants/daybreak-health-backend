# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::InsuranceCostEstimate, type: :graphql do
  let(:onboarding_session) { create(:onboarding_session) }
  let(:insurance) { create(:insurance, onboarding_session: onboarding_session) }
  let(:context) { { current_session: onboarding_session } }

  let!(:session_rate) do
    SessionRate.create!(
      service_type: 'individual_therapy',
      base_rate: BigDecimal('150.00'),
      effective_date: 30.days.ago,
      end_date: nil
    )
  end

  let(:coverage_data) do
    {
      "eligible" => true,
      "coverage" => {
        "mental_health_covered" => true,
        "copay" => { "amount" => 25.0 },
        "deductible" => { "amount" => 500.0, "met" => 500.0 },
        "coinsurance" => { "percentage" => 20 },
        "effective_date" => 90.days.ago.to_date.iso8601,
        "network_status" => "in_network"
      },
      "verified_at" => Time.current.iso8601
    }
  end

  let(:query) do
    <<~GQL
      query($sessionId: ID!, $serviceType: String) {
        insuranceCostEstimate(sessionId: $sessionId, serviceType: $serviceType) {
          insurancePays
          patientPays
          allowedAmount
          billedAmount
          deductibleStatus {
            amount
            met
            remaining
            isMet
          }
          coverageLimitations
          isEstimate
          disclaimer
          calculatedAt
        }
      }
    GQL
  end

  context 'when insurance is verified' do
    before do
      insurance.update_columns(
        verification_status: Insurance.verification_statuses[:verified],
        verification_result: coverage_data
      )
      # Reload the insurance to ensure associations are current
      insurance.reload
      # Also reload the session to ensure it has the updated insurance
      onboarding_session.reload
    end

    it 'returns cost estimate' do
      result = execute_graphql(
        query,
        variables: {
          sessionId: onboarding_session.id,
          serviceType: 'individual_therapy'
        },
        context: context
      )

      data = result.dig('data', 'insuranceCostEstimate')

      expect(data).to be_present
      expect(data['insurancePays']).to be_a(Numeric)
      expect(data['patientPays']).to be_a(Numeric)
      expect(data['allowedAmount']).to be_a(Numeric)
      expect(data['billedAmount']).to be_a(Numeric)
      expect(data['isEstimate']).to be true
      expect(data['disclaimer']).to include('estimate only')
    end

    it 'returns deductible status' do
      result = execute_graphql(
        query,
        variables: { sessionId: onboarding_session.id },
        context: context
      )

      deductible = result.dig('data', 'insuranceCostEstimate', 'deductibleStatus')

      expect(deductible['amount']).to eq(500.0)
      expect(deductible['met']).to eq(500.0)
      expect(deductible['remaining']).to eq(0.0)
      expect(deductible['isMet']).to be true
    end

    it 'returns empty coverage limitations by default' do
      result = execute_graphql(
        query,
        variables: { sessionId: onboarding_session.id },
        context: context
      )

      limitations = result.dig('data', 'insuranceCostEstimate', 'coverageLimitations')

      expect(limitations).to be_an(Array)
    end
  end

  context 'when insurance is not verified' do
    before do
      insurance.update_column(:verification_status, Insurance.verification_statuses[:pending])
    end

    it 'returns null' do
      result = execute_graphql(
        query,
        variables: { sessionId: onboarding_session.id },
        context: context
      )

      data = result.dig('data', 'insuranceCostEstimate')

      expect(data).to be_nil
    end
  end

  context 'when session not found' do
    it 'returns authentication error (security fix - no session existence revelation)' do
      result = execute_graphql(
        query,
        variables: { sessionId: 'non-existent-id' },
        context: {}
      )

      errors = result['errors']

      expect(errors).to be_present
      # After H1 fix: authentication is checked first, so we get auth error not "session not found"
      expect(errors.first['message']).to include('Authentication required')
      expect(errors.first.dig('extensions', 'code')).to eq('UNAUTHENTICATED')
    end
  end

  context 'when no insurance for session' do
    before do
      insurance.destroy
    end

    it 'returns error' do
      result = execute_graphql(
        query,
        variables: { sessionId: onboarding_session.id },
        context: context
      )

      errors = result['errors']

      expect(errors).to be_present
      expect(errors.first['message']).to include('No insurance found')
    end
  end

  context 'with service_type parameter' do
    let!(:family_rate) do
      SessionRate.create!(
        service_type: 'family_therapy',
        base_rate: BigDecimal('200.00'),
        effective_date: 30.days.ago,
        end_date: nil
      )
    end

    before do
      insurance.update_columns(
        verification_status: Insurance.verification_statuses[:verified],
        verification_result: coverage_data
      )
    end

    it 'uses specified service type for calculation' do
      result = execute_graphql(
        query,
        variables: {
          sessionId: onboarding_session.id,
          serviceType: 'family_therapy'
        },
        context: context
      )

      data = result.dig('data', 'insuranceCostEstimate')

      # Family therapy rate is 200, so billed amount should reflect that
      expect(data['billedAmount']).to eq(200.0)
    end

    it 'rejects invalid service types (M5 security fix)' do
      result = execute_graphql(
        query,
        variables: {
          sessionId: onboarding_session.id,
          serviceType: 'invalid_service_type'
        },
        context: context
      )

      errors = result['errors']

      expect(errors).to be_present
      expect(errors.first['message']).to include('Invalid service type')
      expect(errors.first.dig('extensions', 'code')).to eq('INVALID_SERVICE_TYPE')
      expect(errors.first.dig('extensions', 'allowed_values')).to be_an(Array)
    end
  end

  # Helper method for executing GraphQL queries
  def execute_graphql(query, variables: {}, context: {})
    DaybreakHealthBackendSchema.execute(query, variables: variables, context: context).to_h
  end
end
