# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'paymentPlanOptions query', type: :graphql do
  let(:query) do
    <<~GRAPHQL
      query PaymentPlanOptions($sessionId: ID!, $estimatedCost: Float!) {
        paymentPlanOptions(sessionId: $sessionId, estimatedCost: $estimatedCost) {
          durationMonths
          monthlyAmount
          totalAmount
          interestRate
          hasFees
          feeAmount
          upfrontDiscount
          description
        }
      }
    GRAPHQL
  end

  let(:session) { create(:onboarding_session, :with_parent, :with_child) }
  let(:estimated_cost) { 1200.00 }
  let(:variables) { { sessionId: session.id, estimatedCost: estimated_cost } }

  def execute_query(user_session: session)
    DaybreakHealthBackendSchema.execute(
      query,
      variables: variables,
      context: {
        current_session: user_session,
        ip_address: '127.0.0.1',
        user_agent: 'RSpec Test'
      }
    )
  end

  context 'with valid authenticated session' do
    let(:result) { execute_query }
    let(:payment_plans) { result.dig('data', 'paymentPlanOptions') }

    it 'returns successful response' do
      expect(result['errors']).to be_nil
    end

    it 'returns payment plan options array' do
      expect(payment_plans).to be_an(Array)
      expect(payment_plans.length).to eq(4) # 1 upfront + 3 monthly plans
    end

    it 'includes upfront payment option with discount' do
      upfront_plan = payment_plans.find { |p| p['durationMonths'] == 0 }

      expect(upfront_plan).to be_present
      expect(upfront_plan['monthlyAmount']).to eq(1140.00)
      expect(upfront_plan['totalAmount']).to eq(1140.00)
      expect(upfront_plan['upfrontDiscount']).to eq(5.0)
      expect(upfront_plan['interestRate']).to eq(0.0)
      expect(upfront_plan['hasFees']).to be false
      expect(upfront_plan['feeAmount']).to eq(0.0)
      expect(upfront_plan['description']).to include('Pay in full')
      expect(upfront_plan['description']).to include('5.0% discount')
    end

    it 'includes 3-month payment plan' do
      plan_3 = payment_plans.find { |p| p['durationMonths'] == 3 }

      expect(plan_3).to be_present
      expect(plan_3['monthlyAmount']).to eq(400.00)
      expect(plan_3['totalAmount']).to eq(1200.00)
      expect(plan_3['interestRate']).to eq(0.0)
      expect(plan_3['hasFees']).to be false
      expect(plan_3['feeAmount']).to eq(0.0)
      expect(plan_3['upfrontDiscount']).to be_nil
      expect(plan_3['description']).to include('3 monthly payments')
    end

    it 'includes 6-month payment plan' do
      plan_6 = payment_plans.find { |p| p['durationMonths'] == 6 }

      expect(plan_6).to be_present
      expect(plan_6['monthlyAmount']).to eq(200.00)
      expect(plan_6['totalAmount']).to eq(1200.00)
      expect(plan_6['interestRate']).to eq(0.0)
      expect(plan_6['hasFees']).to be false
      expect(plan_6['description']).to include('6 monthly payments')
    end

    it 'includes 12-month payment plan' do
      plan_12 = payment_plans.find { |p| p['durationMonths'] == 12 }

      expect(plan_12).to be_present
      expect(plan_12['monthlyAmount']).to eq(100.00)
      expect(plan_12['totalAmount']).to eq(1200.00)
      expect(plan_12['interestRate']).to eq(0.0)
      expect(plan_12['hasFees']).to be false
      expect(plan_12['description']).to include('12 monthly payments')
    end

    it 'all plans have required fields' do
      payment_plans.each do |plan|
        expect(plan).to have_key('durationMonths')
        expect(plan).to have_key('monthlyAmount')
        expect(plan).to have_key('totalAmount')
        expect(plan).to have_key('interestRate')
        expect(plan).to have_key('hasFees')
        expect(plan).to have_key('feeAmount')
        expect(plan).to have_key('description')
      end
    end
  end

  context 'with different estimated costs' do
    context 'with small cost' do
      let(:estimated_cost) { 300.00 }
      let(:result) { execute_query }
      let(:payment_plans) { result.dig('data', 'paymentPlanOptions') }

      it 'calculates plans correctly' do
        upfront_plan = payment_plans.find { |p| p['durationMonths'] == 0 }
        expect(upfront_plan['totalAmount']).to eq(285.00) # 300 * 0.95

        plan_3 = payment_plans.find { |p| p['durationMonths'] == 3 }
        expect(plan_3['monthlyAmount']).to eq(100.00)
        expect(plan_3['totalAmount']).to eq(300.00)
      end
    end

    context 'with large cost' do
      let(:estimated_cost) { 10_000.00 }
      let(:result) { execute_query }
      let(:payment_plans) { result.dig('data', 'paymentPlanOptions') }

      it 'calculates plans correctly' do
        upfront_plan = payment_plans.find { |p| p['durationMonths'] == 0 }
        expect(upfront_plan['totalAmount']).to eq(9500.00) # 10000 * 0.95

        plan_12 = payment_plans.find { |p| p['durationMonths'] == 12 }
        expect(plan_12['monthlyAmount']).to eq(833.33)
        expect(plan_12['totalAmount']).to eq(10_000.00)
      end
    end

    context 'with amount that does not divide evenly' do
      let(:estimated_cost) { 1000.00 }
      let(:result) { execute_query }
      let(:payment_plans) { result.dig('data', 'paymentPlanOptions') }

      it 'handles rounding correctly' do
        plan_3 = payment_plans.find { |p| p['durationMonths'] == 3 }
        # 1000 / 3 = 333.33 (rounded)
        expect(plan_3['monthlyAmount']).to eq(333.33)
        # Total should remain 1000
        expect(plan_3['totalAmount']).to eq(1000.00)
      end
    end
  end

  context 'with sess_ prefixed session ID' do
    let(:sess_id) { "sess_#{session.id.delete('-')}" }
    let(:variables) { { sessionId: sess_id, estimatedCost: estimated_cost } }
    let(:result) { execute_query }

    it 'handles sess_ prefix correctly' do
      expect(result['errors']).to be_nil
      payment_plans = result.dig('data', 'paymentPlanOptions')
      expect(payment_plans).to be_an(Array)
      expect(payment_plans.length).to eq(4)
    end
  end

  context 'with authentication errors' do
    context 'when session not found' do
      let(:variables) { { sessionId: SecureRandom.uuid, estimatedCost: estimated_cost } }
      let(:result) { execute_query }

      it 'returns NOT_FOUND error' do
        expect(result['errors']).to be_present
        error = result['errors'].first
        expect(error['message']).to include('Session not found')
        expect(error['extensions']['code']).to eq('NOT_FOUND')
      end
    end

    context 'when user does not have access to session' do
      let(:other_session) { create(:onboarding_session) }
      let(:result) { execute_query(user_session: other_session) }

      it 'returns UNAUTHENTICATED error' do
        expect(result['errors']).to be_present
        error = result['errors'].first
        expect(error['message']).to include('Access denied')
        expect(error['extensions']['code']).to eq('UNAUTHENTICATED')
      end
    end

    context 'when no session in context' do
      let(:result) do
        DaybreakHealthBackendSchema.execute(
          query,
          variables: variables,
          context: {
            current_session: nil,
            ip_address: '127.0.0.1',
            user_agent: 'RSpec Test'
          }
        )
      end

      it 'returns UNAUTHENTICATED error' do
        expect(result['errors']).to be_present
        error = result['errors'].first
        expect(error['message']).to include('Access denied')
        expect(error['extensions']['code']).to eq('UNAUTHENTICATED')
      end
    end
  end

  context 'with validation errors' do
    context 'when estimated cost is zero' do
      let(:estimated_cost) { 0.0 }
      let(:result) { execute_query }

      it 'returns INVALID_INPUT error' do
        expect(result['errors']).to be_present
        error = result['errors'].first
        expect(error['message']).to include('Invalid input')
        expect(error['extensions']['code']).to eq('INVALID_INPUT')
      end
    end

    context 'when estimated cost is negative' do
      let(:estimated_cost) { -100.0 }
      let(:result) { execute_query }

      it 'returns INVALID_INPUT error' do
        expect(result['errors']).to be_present
        error = result['errors'].first
        expect(error['message']).to include('Invalid input')
        expect(error['extensions']['code']).to eq('INVALID_INPUT')
      end
    end
  end

  context 'with MVP constraints' do
    let(:result) { execute_query }
    let(:payment_plans) { result.dig('data', 'paymentPlanOptions') }

    it 'uses 0% interest rate for all plans' do
      payment_plans.each do |plan|
        expect(plan['interestRate']).to eq(0.0)
      end
    end

    it 'has no fees for all plans' do
      monthly_plans = payment_plans.reject { |p| p['durationMonths'] == 0 }
      monthly_plans.each do |plan|
        expect(plan['hasFees']).to be false
        expect(plan['feeAmount']).to eq(0.0)
      end
    end

    it 'ensures transparent pricing (no predatory terms)' do
      monthly_plans = payment_plans.reject { |p| p['durationMonths'] == 0 }
      monthly_plans.each do |plan|
        # Monthly amount * duration should equal total (within rounding tolerance)
        calculated_total = plan['monthlyAmount'] * plan['durationMonths']
        difference = (calculated_total - plan['totalAmount']).abs
        # Allow for small rounding differences (within $0.10)
        expect(difference).to be < 0.10
      end
    end
  end

  context 'integration with OnboardingSession' do
    let(:result) { execute_query }

    it 'associates with existing session' do
      payment_plans = result.dig('data', 'paymentPlanOptions')
      expect(payment_plans).to be_present

      # Verify session still exists and is not modified
      session.reload
      expect(session).to be_persisted
    end

    it 'does not modify session data' do
      expect {
        execute_query
      }.not_to change { session.reload.attributes }
    end
  end
end
