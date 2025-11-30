# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Billing::UpdateDeductibleOverride, type: :graphql do
  let(:onboarding_session) { create(:onboarding_session) }
  let(:insurance) { create(:insurance, :verified, onboarding_session: onboarding_session) }

  let(:mutation) do
    <<~GQL
      mutation($input: UpdateDeductibleOverrideInput!) {
        updateDeductibleOverride(input: $input) {
          insurance {
            id
            verificationStatus
          }
          errors
        }
      }
    GQL
  end

  let(:context) do
    {
      current_session: onboarding_session,
      current_session_id: onboarding_session.id
    }
  end

  before do
    # Set up initial verification result
    insurance.verification_result = {
      "verified_at" => 1.hour.ago.iso8601,
      "coverage" => {
        "deductible" => {
          "amount" => 500.0,
          "met" => 100.0
        },
        "out_of_pocket_max" => {
          "amount" => 3000.0,
          "met" => 500.0
        }
      }
    }
    insurance.save!
  end

  describe 'successful override' do
    let(:input) do
      {
        sessionId: onboarding_session.id,
        deductibleMet: 250.0,
        oopMet: 750.0,
        overrideReason: "Patient provided updated EOB showing higher amounts"
      }
    end

    it 'updates deductible and OOP met values' do
      result = DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { input: input },
        context: context
      )

      expect(result['errors']).to be_nil

      data = result['data']['updateDeductibleOverride']
      expect(data['errors']).to be_empty
      expect(data['insurance']).not_to be_nil

      # Verify override was saved
      insurance.reload
      override = insurance.verification_result['deductible_override']

      expect(override['deductible_met']).to eq(250.0)
      expect(override['oop_met']).to eq(750.0)
      expect(override['override_reason']).to eq("Patient provided updated EOB showing higher amounts")
      expect(override['override_by']).to eq(onboarding_session.id)
      expect(override['source']).to eq('manual')
      expect(override['override_timestamp']).not_to be_nil
    end

    it 'creates audit log with override details' do
      DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { input: input },
        context: context
      )

      audit_log = AuditLog.where(action: 'DEDUCTIBLE_OVERRIDE').last
      expect(audit_log).not_to be_nil
      expect(audit_log.resource).to eq('Insurance')
      expect(audit_log.onboarding_session_id).to eq(onboarding_session.id)
      expect(audit_log.details['insurance_id']).to eq(insurance.id)
      expect(audit_log.details['override_reason']).to eq("Patient provided updated EOB showing higher amounts")
      expect(audit_log.details['fields_updated']).to match_array(['deductible_met', 'oop_met'])
    end
  end

  describe 'partial override' do
    context 'updating only deductible met' do
      let(:input) do
        {
          sessionId: onboarding_session.id,
          deductibleMet: 200.0,
          overrideReason: "EOB shows updated deductible progress"
        }
      end

      it 'updates only deductible met field' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { input: input },
          context: context
        )

        expect(result['errors']).to be_nil
        expect(result['data']['updateDeductibleOverride']['errors']).to be_empty

        insurance.reload
        override = insurance.verification_result['deductible_override']

        expect(override['deductible_met']).to eq(200.0)
        expect(override['oop_met']).to be_nil # Not updated
      end
    end

    context 'updating only OOP met' do
      let(:input) do
        {
          sessionId: onboarding_session.id,
          oopMet: 900.0,
          overrideReason: "Patient hit OOP max faster than expected"
        }
      end

      it 'updates only OOP met field' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { input: input },
          context: context
        )

        expect(result['errors']).to be_nil
        expect(result['data']['updateDeductibleOverride']['errors']).to be_empty

        insurance.reload
        override = insurance.verification_result['deductible_override']

        expect(override['oop_met']).to eq(900.0)
        expect(override['deductible_met']).to be_nil # Not updated
      end
    end
  end

  describe 'total amount overrides' do
    let(:input) do
      {
        sessionId: onboarding_session.id,
        deductibleAmount: 750.0,
        oopMaxAmount: 4000.0,
        overrideReason: "Incorrect plan details from API, patient confirmed actual amounts"
      }
    end

    it 'overrides total deductible and OOP max amounts' do
      result = DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { input: input },
        context: context
      )

      expect(result['errors']).to be_nil
      expect(result['data']['updateDeductibleOverride']['errors']).to be_empty

      insurance.reload
      override = insurance.verification_result['deductible_override']

      expect(override['deductible_amount']).to eq(750.0)
      expect(override['oop_max_amount']).to eq(4000.0)
    end
  end

  describe 'multiple override updates' do
    it 'preserves override history' do
      # First override
      first_input = {
        sessionId: onboarding_session.id,
        deductibleMet: 150.0,
        overrideReason: "First EOB received"
      }

      DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { input: first_input },
        context: context
      )

      first_timestamp = insurance.reload.verification_result['deductible_override']['override_timestamp']

      travel 1.hour

      # Second override
      second_input = {
        sessionId: onboarding_session.id,
        deductibleMet: 300.0,
        overrideReason: "Second EOB received with updated amount"
      }

      DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { input: second_input },
        context: context
      )

      insurance.reload
      override = insurance.verification_result['deductible_override']

      expect(override['deductible_met']).to eq(300.0)
      expect(override['override_reason']).to eq("Second EOB received with updated amount")
      expect(override['override_timestamp']).not_to eq(first_timestamp)
      expect(Time.parse(override['override_timestamp'])).to be > Time.parse(first_timestamp)
    end
  end

  describe 'validation errors' do
    context 'when override reason is missing' do
      let(:input) do
        {
          sessionId: onboarding_session.id,
          deductibleMet: 250.0,
          overrideReason: ""
        }
      end

      it 'returns error for missing reason' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { input: input },
          context: context
        )

        data = result['data']['updateDeductibleOverride']
        expect(data['insurance']).to be_nil
        expect(data['errors']).to include("Override reason is required")
      end
    end

    context 'when session not found' do
      let(:input) do
        {
          sessionId: 'nonexistent-id',
          deductibleMet: 250.0,
          overrideReason: "Test"
        }
      end

      it 'returns error' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { input: input },
          context: context
        )

        data = result['data']['updateDeductibleOverride']
        expect(data['insurance']).to be_nil
        expect(data['errors']).to include("Session not found")
      end
    end

    context 'when insurance not found for session' do
      before do
        insurance.destroy
      end

      let(:input) do
        {
          sessionId: onboarding_session.id,
          deductibleMet: 250.0,
          overrideReason: "Test"
        }
      end

      it 'returns error' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { input: input },
          context: context
        )

        data = result['data']['updateDeductibleOverride']
        expect(data['insurance']).to be_nil
        expect(data['errors']).to include("No insurance found for session")
      end
    end
  end

  describe 'authorization' do
    context 'when accessing another session' do
      let(:other_session) { create(:onboarding_session) }

      let(:input) do
        {
          sessionId: other_session.id,
          deductibleMet: 250.0,
          overrideReason: "Test"
        }
      end

      it 'denies access' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { input: input },
          context: context
        )

        data = result['data']['updateDeductibleOverride']
        expect(data['insurance']).to be_nil
        expect(data['errors']).to include("Access denied")
      end
    end
  end

  describe 'integration with deductible tracker' do
    it 'override values are used by tracker service' do
      # Apply override
      input = {
        sessionId: onboarding_session.id,
        deductibleMet: 300.0,
        oopMet: 800.0,
        overrideReason: "Manual update from patient EOB"
      }

      DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { input: input },
        context: context
      )

      # Verify tracker uses override values
      insurance.reload
      tracker = Billing::DeductibleTracker.new(insurance: insurance)
      status = tracker.current_status

      expect(status[:deductible_met]).to eq(300.0)
      expect(status[:oop_met]).to eq(800.0)
      expect(status[:data_source]).to eq('manual_override')
    end
  end

  describe 'edge cases' do
    context 'with negative values' do
      let(:input) do
        {
          sessionId: onboarding_session.id,
          deductibleMet: -50.0,
          overrideReason: "Testing negative value"
        }
      end

      it 'rejects negative values' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { input: input },
          context: context
        )

        # Mutation fails with validation error
        data = result['data']['updateDeductibleOverride']
        expect(data['insurance']).to be_nil
        expect(data['errors']).to include("Deductible met cannot be negative")
      end
    end

    context 'with zero values' do
      let(:input) do
        {
          sessionId: onboarding_session.id,
          deductibleMet: 0.0,
          oopMet: 0.0,
          overrideReason: "Reset to beginning of plan year"
        }
      end

      it 'allows zero values' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { input: input },
          context: context
        )

        expect(result['data']['updateDeductibleOverride']['errors']).to be_empty

        insurance.reload
        override = insurance.verification_result['deductible_override']
        expect(override['deductible_met']).to eq(0.0)
        expect(override['oop_met']).to eq(0.0)
      end
    end

    context 'with very large values' do
      let(:input) do
        {
          sessionId: onboarding_session.id,
          deductibleMet: 999999.99,
          oopMet: 999999.99,
          overrideReason: "Testing large values"
        }
      end

      it 'handles large values' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { input: input },
          context: context
        )

        expect(result['data']['updateDeductibleOverride']['errors']).to be_empty

        insurance.reload
        override = insurance.verification_result['deductible_override']
        expect(override['deductible_met']).to eq(999999.99)
        expect(override['oop_met']).to eq(999999.99)
      end
    end

    context 'with excessive values' do
      let(:input) do
        {
          sessionId: onboarding_session.id,
          deductibleMet: 2_000_000.0,
          overrideReason: "Testing excessive value"
        }
      end

      it 'rejects values over reasonable maximum' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { input: input },
          context: context
        )

        data = result['data']['updateDeductibleOverride']
        expect(data['insurance']).to be_nil
        expect(data['errors']).to include("Deductible met exceeds reasonable maximum ($1000000)")
      end
    end

    context 'with inconsistent met vs amount values' do
      let(:input) do
        {
          sessionId: onboarding_session.id,
          deductibleMet: 1000.0,
          deductibleAmount: 500.0,
          overrideReason: "Testing inconsistent values"
        }
      end

      it 'rejects when met exceeds amount' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { input: input },
          context: context
        )

        data = result['data']['updateDeductibleOverride']
        expect(data['insurance']).to be_nil
        expect(data['errors']).to include("Deductible met cannot exceed deductible amount")
      end
    end

    context 'with inconsistent OOP met vs max values' do
      let(:input) do
        {
          sessionId: onboarding_session.id,
          oopMet: 5000.0,
          oopMaxAmount: 3000.0,
          overrideReason: "Testing inconsistent OOP values"
        }
      end

      it 'rejects when OOP met exceeds OOP max' do
        result = DaybreakHealthBackendSchema.execute(
          mutation,
          variables: { input: input },
          context: context
        )

        data = result['data']['updateDeductibleOverride']
        expect(data['insurance']).to be_nil
        expect(data['errors']).to include("OOP met cannot exceed OOP max amount")
      end
    end
  end

  describe 'enhanced audit trail' do
    it 'captures previous values in audit log' do
      # Set up initial override
      insurance.verification_result = {
        "deductible_override" => {
          "deductible_met" => 100.0,
          "oop_met" => 200.0,
          "override_timestamp" => 1.hour.ago.iso8601,
          "override_reason" => "Initial override"
        }
      }
      insurance.save!

      # Apply new override
      input = {
        sessionId: onboarding_session.id,
        deductibleMet: 250.0,
        oopMet: 400.0,
        overrideReason: "Updated EOB received"
      }

      DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { input: input },
        context: context
      )

      audit_log = AuditLog.where(action: 'DEDUCTIBLE_OVERRIDE').last
      expect(audit_log).not_to be_nil
      expect(audit_log.resource).to eq('Insurance')
      expect(audit_log.details['new_values']['deductible_met']).to eq(250.0)
      expect(audit_log.details['new_values']['oop_met']).to eq(400.0)
      expect(audit_log.details['previous_values']['deductible_met']).to eq(100.0)
      expect(audit_log.details['previous_values']['oop_met']).to eq(200.0)
      expect(audit_log.details['previous_values']['override_reason']).to eq("Initial override")
    end

    it 'includes resource field in audit log' do
      input = {
        sessionId: onboarding_session.id,
        deductibleMet: 250.0,
        overrideReason: "Testing resource field"
      }

      DaybreakHealthBackendSchema.execute(
        mutation,
        variables: { input: input },
        context: context
      )

      audit_log = AuditLog.where(action: 'DEDUCTIBLE_OVERRIDE').last
      expect(audit_log).not_to be_nil
      expect(audit_log.resource).to eq('Insurance')
      expect(audit_log.action).to eq('DEDUCTIBLE_OVERRIDE')
    end
  end
end
