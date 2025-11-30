# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Billing::SavePaymentPlanSelection, type: :graphql do
  let(:mutation) do
    <<~GRAPHQL
      mutation SavePaymentPlanSelection($input: SavePaymentPlanSelectionInput!) {
        savePaymentPlanSelection(input: $input) {
          success
          message
          paymentPlan {
            id
            planDurationMonths
            monthlyAmount
            totalAmount
            discountApplied
            paymentMethodPreference
            status
            description
          }
        }
      }
    GRAPHQL
  end

  let(:session) { create(:onboarding_session, :with_parent, :with_child) }
  let(:variables) do
    {
      input: {
        sessionId: session.id,
        planDurationMonths: 3,
        monthlyAmount: 400.00,
        totalAmount: 1200.00,
        discountApplied: 0.0,
        paymentMethodPreference: 'CARD'
      }
    }
  end

  def execute_mutation(user_session: session, vars: variables)
    DaybreakHealthBackendSchema.execute(
      mutation,
      variables: vars,
      context: {
        current_session: user_session,
        ip_address: '127.0.0.1',
        user_agent: 'RSpec Test'
      }
    )
  end

  context 'with valid inputs' do
    let(:result) { execute_mutation }
    let(:payment_plan_data) { result.dig('data', 'savePaymentPlanSelection', 'paymentPlan') }

    it 'returns successful response' do
      expect(result['errors']).to be_nil
    end

    it 'indicates success' do
      expect(result.dig('data', 'savePaymentPlanSelection', 'success')).to be true
      expect(result.dig('data', 'savePaymentPlanSelection', 'message')).to include('saved successfully')
    end

    it 'creates payment plan record' do
      expect {
        execute_mutation
      }.to change(PaymentPlan, :count).by(1)
    end

    it 'links payment plan to session' do
      execute_mutation
      payment_plan = PaymentPlan.last

      expect(payment_plan.onboarding_session_id).to eq(session.id)
    end

    it 'stores plan details correctly' do
      expect(payment_plan_data['planDurationMonths']).to eq(3)
      expect(payment_plan_data['monthlyAmount']).to eq(400.00)
      expect(payment_plan_data['totalAmount']).to eq(1200.00)
      expect(payment_plan_data['discountApplied']).to eq(0.0)
      expect(payment_plan_data['paymentMethodPreference']).to eq('CARD')
    end

    it 'sets status to pending' do
      expect(payment_plan_data['status']).to eq('pending')
    end

    it 'returns payment plan with description' do
      expect(payment_plan_data['description']).to be_present
      expect(payment_plan_data['description']).to include('3 monthly payments')
    end

    it 'creates audit log entry' do
      # Session creation creates audit logs for parent and child, so count from baseline
      baseline_count = AuditLog.count

      execute_mutation

      # Find the payment plan selection audit log
      audit_log = AuditLog.where(action: 'PAYMENT_PLAN_SELECTED').last
      expect(audit_log).to be_present
      expect(audit_log.resource).to eq('PaymentPlan')
      expect(audit_log.onboarding_session_id).to eq(session.id)
      expect(audit_log.details['plan_duration_months']).to eq(3)
      expect(audit_log.details['monthly_amount']).to eq('400.0')
      expect(audit_log.details['total_amount']).to eq('1200.0')
      expect(audit_log.details['payment_method_preference']).to eq('card')
    end
  end

  context 'with upfront payment plan' do
    let(:upfront_variables) do
      {
        input: {
          sessionId: session.id,
          planDurationMonths: 0,
          monthlyAmount: 1140.00,
          totalAmount: 1140.00,
          discountApplied: 60.00,
          paymentMethodPreference: 'CARD'
        }
      }
    end
    let(:result) { execute_mutation(vars: upfront_variables) }
    let(:payment_plan_data) { result.dig('data', 'savePaymentPlanSelection', 'paymentPlan') }

    it 'creates upfront payment plan' do
      expect(payment_plan_data['planDurationMonths']).to eq(0)
      expect(payment_plan_data['monthlyAmount']).to eq(1140.00)
      expect(payment_plan_data['totalAmount']).to eq(1140.00)
      expect(payment_plan_data['discountApplied']).to eq(60.00)
    end

    it 'has description indicating upfront payment' do
      expect(payment_plan_data['description']).to include('Pay in full')
    end
  end

  context 'with different payment methods' do
    context 'with HSA/FSA payment method' do
      let(:hsa_variables) do
        { input: variables[:input].merge(paymentMethodPreference: 'HSA_FSA') }
      end
      let(:result) { execute_mutation(vars: hsa_variables) }
      let(:payment_plan_data) { result.dig('data', 'savePaymentPlanSelection', 'paymentPlan') }

      it 'saves HSA/FSA as payment method' do
        expect(payment_plan_data['paymentMethodPreference']).to eq('HSA_FSA')
      end
    end

    context 'with bank transfer payment method' do
      let(:bank_variables) do
        { input: variables[:input].merge(paymentMethodPreference: 'BANK_TRANSFER') }
      end
      let(:result) { execute_mutation(vars: bank_variables) }
      let(:payment_plan_data) { result.dig('data', 'savePaymentPlanSelection', 'paymentPlan') }

      it 'saves bank transfer as payment method' do
        expect(payment_plan_data['paymentMethodPreference']).to eq('BANK_TRANSFER')
      end
    end
  end

  context 'with optional discount applied' do
    let(:discount_variables) do
      {
        input: variables[:input].merge(
          monthlyAmount: 380.00,
          totalAmount: 1140.00,
          discountApplied: 60.00
        )
      }
    end
    let(:result) { execute_mutation(vars: discount_variables) }
    let(:payment_plan_data) { result.dig('data', 'savePaymentPlanSelection', 'paymentPlan') }

    it 'stores discount amount' do
      expect(payment_plan_data['discountApplied']).to eq(60.00)
    end
  end

  context 'with sess_ prefixed session ID' do
    let(:sess_id) { "sess_#{session.id.delete('-')}" }
    let(:sess_variables) do
      { input: variables[:input].merge(sessionId: sess_id) }
    end
    let(:result) { execute_mutation(vars: sess_variables) }

    it 'handles sess_ prefix correctly' do
      expect(result['errors']).to be_nil
      expect(result.dig('data', 'savePaymentPlanSelection', 'success')).to be true
    end

    it 'creates payment plan linked to correct session' do
      execute_mutation(vars: sess_variables)
      payment_plan = PaymentPlan.last

      expect(payment_plan.onboarding_session_id).to eq(session.id)
    end
  end

  context 'with authentication errors' do
    context 'when session not found' do
      let(:invalid_variables) do
        { input: variables[:input].merge(sessionId: SecureRandom.uuid) }
      end
      let(:result) { execute_mutation(vars: invalid_variables) }

      it 'returns NOT_FOUND error' do
        expect(result['errors']).to be_present
        error = result['errors'].first
        expect(error['message']).to include('Session not found')
        expect(error['extensions']['code']).to eq('NOT_FOUND')
      end

      it 'does not create payment plan' do
        expect {
          execute_mutation(vars: invalid_variables)
        }.not_to change(PaymentPlan, :count)
      end
    end

    context 'when user does not have access to session' do
      let(:other_session) { create(:onboarding_session) }
      let(:result) { execute_mutation(user_session: other_session) }

      it 'returns UNAUTHENTICATED error' do
        expect(result['errors']).to be_present
        error = result['errors'].first
        expect(error['message']).to include('Access denied')
        expect(error['extensions']['code']).to eq('UNAUTHENTICATED')
      end

      it 'does not create payment plan' do
        expect {
          execute_mutation(user_session: other_session)
        }.not_to change(PaymentPlan, :count)
      end
    end

    context 'when no session in context' do
      let(:result) do
        DaybreakHealthBackendSchema.execute(
          mutation,
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
    context 'when plan duration is negative' do
      let(:invalid_variables) do
        { input: variables[:input].merge(planDurationMonths: -1) }
      end
      let(:result) { execute_mutation(vars: invalid_variables) }

      it 'returns INVALID_INPUT error' do
        expect(result['errors']).to be_present
        error = result['errors'].first
        expect(error['message']).to include('Invalid payment plan')
        expect(error['extensions']['code']).to eq('INVALID_INPUT')
      end
    end

    context 'when monthly amount is zero' do
      let(:invalid_variables) do
        { input: variables[:input].merge(monthlyAmount: 0.0) }
      end
      let(:result) { execute_mutation(vars: invalid_variables) }

      it 'returns INVALID_INPUT error' do
        expect(result['errors']).to be_present
        error = result['errors'].first
        expect(error['message']).to include('Invalid payment plan')
        expect(error['extensions']['code']).to eq('INVALID_INPUT')
      end
    end

    context 'when monthly amount is negative' do
      let(:invalid_variables) do
        { input: variables[:input].merge(monthlyAmount: -100.0) }
      end
      let(:result) { execute_mutation(vars: invalid_variables) }

      it 'returns INVALID_INPUT error' do
        expect(result['errors']).to be_present
        error = result['errors'].first
        expect(error['message']).to include('Invalid payment plan')
        expect(error['extensions']['code']).to eq('INVALID_INPUT')
      end
    end

    context 'when total amount is zero' do
      let(:invalid_variables) do
        { input: variables[:input].merge(totalAmount: 0.0) }
      end
      let(:result) { execute_mutation(vars: invalid_variables) }

      it 'returns INVALID_INPUT error' do
        expect(result['errors']).to be_present
        error = result['errors'].first
        expect(error['message']).to include('Invalid payment plan')
      end
    end

    context 'when discount applied is negative' do
      let(:invalid_variables) do
        { input: variables[:input].merge(discountApplied: -10.0) }
      end
      let(:result) { execute_mutation(vars: invalid_variables) }

      it 'returns INVALID_INPUT error' do
        expect(result['errors']).to be_present
        error = result['errors'].first
        expect(error['message']).to include('Invalid payment plan')
      end
    end
  end

  context 'integration with OnboardingSession' do
    let(:result) { execute_mutation }

    it 'can be accessed from session' do
      execute_mutation
      session.reload

      expect(session.payment_plan).to be_present
      expect(session.payment_plan.plan_duration_months).to eq(3)
    end

    it 'maintains session integrity' do
      expect {
        execute_mutation
      }.not_to change { session.reload.status }
    end
  end

  context 'idempotency' do
    it 'creates new payment plan each time (allows multiple selections)' do
      # First selection
      execute_mutation
      first_plan_id = PaymentPlan.last.id

      # Second selection (different plan)
      new_variables = {
        input: variables[:input].merge(
          planDurationMonths: 6,
          monthlyAmount: 200.00
        )
      }

      expect {
        execute_mutation(vars: new_variables)
      }.to change(PaymentPlan, :count).by(1)

      # Verify latest plan is the 6-month plan
      latest_plan = PaymentPlan.last
      expect(latest_plan.id).not_to eq(first_plan_id)
      expect(latest_plan.plan_duration_months).to eq(6)
      expect(latest_plan.onboarding_session_id).to eq(session.id)
    end
  end

  context 'audit trail' do
    it 'includes IP address in audit log' do
      execute_mutation
      audit_log = AuditLog.where(action: 'PAYMENT_PLAN_SELECTED').last

      expect(audit_log.ip_address).to eq('127.0.0.1')
    end

    it 'includes user agent in audit log' do
      execute_mutation
      audit_log = AuditLog.where(action: 'PAYMENT_PLAN_SELECTED').last

      expect(audit_log.user_agent).to eq('RSpec Test')
    end

    it 'includes timestamp in audit log details' do
      execute_mutation
      audit_log = AuditLog.where(action: 'PAYMENT_PLAN_SELECTED').last

      expect(audit_log.details['timestamp']).to be_present
    end
  end

  context 'MVP constraints' do
    it 'does not perform actual payment processing' do
      result = execute_mutation

      # Payment plan is created but status is pending
      payment_plan = PaymentPlan.last
      expect(payment_plan.status).to eq('pending')

      # No payment gateway API calls should be made
      # (This is a placeholder for when payment processing is added)
    end

    it 'stores selection for future billing integration' do
      execute_mutation
      payment_plan = PaymentPlan.last

      # Verify all necessary data is stored for future billing
      expect(payment_plan.plan_duration_months).to be_present
      expect(payment_plan.monthly_amount).to be_present
      expect(payment_plan.total_amount).to be_present
      expect(payment_plan.payment_method_preference).to be_present
      expect(payment_plan.onboarding_session_id).to be_present
    end
  end
end
