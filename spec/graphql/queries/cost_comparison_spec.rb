# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::CostComparison, type: :graphql do
  let(:parent) { create(:parent) }
  let(:child) { create(:child) }
  let(:session) { create(:onboarding_session, parent: parent, child: child) }
  let!(:self_pay_rate) { create(:self_pay_rate, base_rate: 75.00) }
  let!(:session_rate) { create(:session_rate, service_type: 'individual_therapy', base_rate: 150.00) }
  let(:context) { { current_session: session } }

  let(:query) do
    <<~GQL
      query CostComparison($sessionId: ID!) {
        costComparison(sessionId: $sessionId) {
          insuranceEstimate {
            perSessionCost
            totalEstimatedCost
            explanation
          }
          selfPayEstimate {
            baseRate
            totalForTypicalTreatment
            slidingScaleInfo
            transparentPricingMessage
            whatIsIncluded
            packageOptions {
              sessions
              totalPrice
              perSessionCost
              savings
              description
            }
          }
          comparisonTable {
            label
            insuranceValue
            selfPayValue
            highlightSelfPay
          }
          recommendation
          savingsIfSelfPay
          highlightSelfPay
        }
      }
    GQL
  end

  describe 'costComparison query' do
    context 'when insurance is not verified' do
      before do
        session.build_insurance(verification_status: :pending)
        session.save!
      end

      it 'returns self-pay estimate only' do
        result = execute_graphql(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        # Debug: check for errors
        if result['errors'].present?
          pp result['errors']
        end

        data = result.dig('data', 'costComparison')

        expect(data).to be_present, "Expected data, got result: #{result.inspect}"
        expect(data['insuranceEstimate']).to be_nil
        expect(data['selfPayEstimate']).to be_present
        expect(data['selfPayEstimate']['baseRate']).to eq('$75.00 per session')
        expect(data['highlightSelfPay']).to be false
      end

      it 'includes transparent pricing message' do
        result = execute_graphql(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        data = result.dig('data', 'costComparison')

        expect(data['selfPayEstimate']['transparentPricingMessage']).to eq('No surprise fees. Price shown is what you pay.')
      end

      it 'includes what is included' do
        result = execute_graphql(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        data = result.dig('data', 'costComparison')

        included = data['selfPayEstimate']['whatIsIncluded']
        expect(included).to include('50-minute session')
        expect(included).to include('Secure messaging between sessions')
      end

      it 'includes package options' do
        result = execute_graphql(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        data = result.dig('data', 'costComparison')

        packages = data['selfPayEstimate']['packageOptions']
        expect(packages).to be_an(Array)
        expect(packages.first['sessions']).to eq(4)
        expect(packages.first['totalPrice']).to eq('$280.00')
      end

      it 'includes comparison table' do
        result = execute_graphql(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        data = result.dig('data', 'costComparison')

        table = data['comparisonTable']
        expect(table).to be_an(Array)
        expect(table).not_to be_empty

        per_session_row = table.find { |r| r['label'] == 'Per Session Cost' }
        expect(per_session_row).to be_present
        expect(per_session_row['selfPayValue']).to eq('$75.00')
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
        session.reload
      end

      it 'returns both estimates' do
        result = execute_graphql(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        data = result.dig('data', 'costComparison')

        expect(data['insuranceEstimate']).to be_present
        expect(data['selfPayEstimate']).to be_present
      end

      it 'highlights self-pay as better option' do
        result = execute_graphql(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        data = result.dig('data', 'costComparison')

        expect(data['highlightSelfPay']).to be true
      end

      it 'calculates savings' do
        result = execute_graphql(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        data = result.dig('data', 'costComparison')

        expect(data['savingsIfSelfPay']).to be_present
        expect(data['savingsIfSelfPay']).to be > 0
      end

      it 'provides recommendation' do
        result = execute_graphql(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        data = result.dig('data', 'costComparison')

        expect(data['recommendation']).to include('Self-pay may be more affordable')
      end

      it 'highlights self-pay in comparison table rows' do
        result = execute_graphql(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        data = result.dig('data', 'costComparison')

        table = data['comparisonTable']
        highlighted_rows = table.select { |r| r['highlightSelfPay'] }
        expect(highlighted_rows).not_to be_empty
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
        session.reload
      end

      it 'does not highlight self-pay' do
        result = execute_graphql(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        data = result.dig('data', 'costComparison')

        expect(data['highlightSelfPay']).to be false
      end

      it 'does not show savings' do
        result = execute_graphql(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        data = result.dig('data', 'costComparison')

        expect(data['savingsIfSelfPay']).to be_nil
      end
    end

    context 'authorization' do
      it 'requires authentication' do
        result = execute_graphql(
          query,
          variables: { sessionId: session.id },
          context: {} # No current_session
        )

        errors = result['errors']
        expect(errors).to be_present
        expect(errors.first['message']).to include('Access denied')
      end

      it 'requires matching session' do
        other_session = create(:onboarding_session)

        result = execute_graphql(
          query,
          variables: { sessionId: other_session.id },
          context: context # context has different session
        )

        errors = result['errors']
        expect(errors).to be_present
        expect(errors.first['message']).to include('Access denied')
      end
    end

    context 'error handling' do
      it 'handles non-existent session' do
        result = execute_graphql(
          query,
          variables: { sessionId: SecureRandom.uuid },
          context: context
        )

        errors = result['errors']
        expect(errors).to be_present
        expect(errors.first['message']).to include('Session not found')
      end
    end
  end
end
