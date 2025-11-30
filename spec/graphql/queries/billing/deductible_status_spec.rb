# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::Billing::DeductibleStatus, type: :graphql do
  let(:onboarding_session) { create(:onboarding_session) }
  let(:insurance) { create(:insurance, :verified, onboarding_session: onboarding_session) }

  let(:query) do
    <<~GQL
      query($sessionId: ID!) {
        deductibleStatus(sessionId: $sessionId) {
          amount
          met
          remaining
          isMet
          deductibleAmount
          deductibleMet
          deductibleRemaining
          oopMaxAmount
          oopMet
          oopRemaining
          isFamilyPlan
          yearResetDate
          progressPercentage
          oopProgressPercentage
          sessionsUntilDeductibleMet
          dataSource
          lastUpdatedAt
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

  describe 'successful query' do
    before do
      insurance.verification_result = {
        "verified_at" => 1.hour.ago.iso8601,
        "coverage" => {
          "deductible" => {
            "amount" => 500.0,
            "met" => 150.0
          },
          "out_of_pocket_max" => {
            "amount" => 3000.0,
            "met" => 600.0
          }
        }
      }
      insurance.save!

      # Set up session rates for projection calculation
      Rails.application.config.session_rates = {
        "individual_therapy" => 100.0
      }
      Rails.application.config.default_session_type = "individual_therapy"
    end

    it 'returns complete deductible status' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: onboarding_session.id },
        context: context
      )

      expect(result['errors']).to be_nil

      data = result['data']['deductibleStatus']
      expect(data).not_to be_nil

      # Core backward compatible fields
      expect(data['amount']).to eq(500.0)
      expect(data['met']).to eq(150.0)
      expect(data['remaining']).to eq(350.0)
      expect(data['isMet']).to be false

      # Enhanced deductible tracking fields
      expect(data['deductibleAmount']).to eq(500.0)
      expect(data['deductibleMet']).to eq(150.0)
      expect(data['deductibleRemaining']).to eq(350.0)

      # OOP max tracking
      expect(data['oopMaxAmount']).to eq(3000.0)
      expect(data['oopMet']).to eq(600.0)
      expect(data['oopRemaining']).to eq(2400.0)

      # Progress indicators
      expect(data['progressPercentage']).to eq(30) # 150/500 * 100
      expect(data['oopProgressPercentage']).to eq(20) # 600/3000 * 100

      # Session projection
      expect(data['sessionsUntilDeductibleMet']).to eq(4) # 350 / 100 = 3.5, rounded up to 4

      # Data provenance
      expect(data['dataSource']).to eq('eligibility_api')
      expect(data['lastUpdatedAt']).not_to be_nil

      # Plan type
      expect(data['isFamilyPlan']).to be false
      expect(data['yearResetDate']).not_to be_nil
    end

    it 'creates audit log for deductible access' do
      DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: onboarding_session.id },
        context: context
      )

      audit_log = AuditLog.where(action: 'DEDUCTIBLE_STATUS_ACCESSED').last
      expect(audit_log).not_to be_nil
      expect(audit_log.resource).to eq('Insurance')
      expect(audit_log.onboarding_session_id).to eq(onboarding_session.id)
      expect(audit_log.details['insurance_id']).to eq(insurance.id)
    end
  end

  describe 'family plan detection' do
    before do
      insurance.verification_result = {
        "coverage" => {
          "family_deductible" => {
            "amount" => 1000.0,
            "met" => 400.0
          },
          "family_out_of_pocket_max" => {
            "amount" => 6000.0,
            "met" => 1200.0
          }
        }
      }
      insurance.save!
    end

    it 'identifies family plan and uses family amounts' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: onboarding_session.id },
        context: context
      )

      data = result['data']['deductibleStatus']

      expect(data['isFamilyPlan']).to be true
      expect(data['deductibleAmount']).to eq(1000.0)
      expect(data['deductibleMet']).to eq(400.0)
      expect(data['oopMaxAmount']).to eq(6000.0)
      expect(data['oopMet']).to eq(1200.0)
    end
  end

  describe 'manual override priority' do
    before do
      insurance.verification_result = {
        "coverage" => {
          "deductible" => {
            "amount" => 500.0,
            "met" => 100.0
          }
        },
        "deductible_override" => {
          "deductible_met" => 300.0,
          "oop_met" => 500.0,
          "override_timestamp" => 30.minutes.ago.iso8601,
          "override_reason" => "Patient provided updated EOB",
          "source" => "manual"
        }
      }
      insurance.save!
    end

    it 'uses override values and indicates manual source' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: onboarding_session.id },
        context: context
      )

      data = result['data']['deductibleStatus']

      expect(data['deductibleMet']).to eq(300.0)
      expect(data['deductibleRemaining']).to eq(200.0) # 500 - 300
      expect(data['oopMet']).to eq(500.0)
      expect(data['dataSource']).to eq('manual_override')
    end
  end

  describe 'authorization' do
    context 'when accessing another session' do
      let(:other_session) { create(:onboarding_session) }

      it 'denies access' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: other_session.id },
          context: context
        )

        expect(result['errors']).not_to be_nil
        expect(result['errors'].first['message']).to include('Access denied')
        expect(result['errors'].first['extensions']['code']).to eq('UNAUTHENTICATED')
      end
    end

    context 'when session not found' do
      it 'returns error' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: 'nonexistent-id' },
          context: context
        )

        expect(result['errors']).not_to be_nil
        expect(result['errors'].first['message']).to include('Session not found')
      end
    end

    context 'when session has no insurance' do
      before do
        insurance.destroy
      end

      it 'returns error' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: onboarding_session.id },
          context: context
        )

        expect(result['errors']).not_to be_nil
        expect(result['errors'].first['message']).to include('No insurance found')
        expect(result['errors'].first['extensions']['code']).to eq('NOT_FOUND')
      end
    end

    context 'when insurance not verified' do
      before do
        insurance.update!(verification_status: :pending)
      end

      it 'returns error with status' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: onboarding_session.id },
          context: context
        )

        expect(result['errors']).not_to be_nil
        expect(result['errors'].first['message']).to include('must be verified')
        expect(result['errors'].first['extensions']['code']).to eq('UNVERIFIED_INSURANCE')
        expect(result['errors'].first['extensions']['status']).to eq('pending')
      end
    end
  end

  describe 'edge cases' do
    context 'when deductible already met' do
      before do
        insurance.verification_result = {
          "coverage" => {
            "deductible" => {
              "amount" => 500.0,
              "met" => 500.0
            }
          }
        }
        insurance.save!
      end

      it 'indicates deductible is met' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: onboarding_session.id },
          context: context
        )

        data = result['data']['deductibleStatus']

        expect(data['isMet']).to be true
        expect(data['remaining']).to eq(0.0)
        expect(data['sessionsUntilDeductibleMet']).to eq(0)
        expect(data['progressPercentage']).to eq(100)
      end
    end

    context 'when no deductible data available' do
      before do
        insurance.verification_result = { "coverage" => {} }
        insurance.save!
      end

      it 'returns default values' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: onboarding_session.id },
          context: context
        )

        data = result['data']['deductibleStatus']

        # Backward compatible fields default to 0
        expect(data['amount']).to eq(0.0)
        expect(data['met']).to eq(0.0)
        expect(data['remaining']).to eq(0.0)
        expect(data['isMet']).to be false

        # Enhanced fields are nil
        expect(data['deductibleAmount']).to be_nil
        expect(data['oopMaxAmount']).to be_nil
      end
    end
  end

  describe 'plan year reset date' do
    context 'with plan year start date' do
      before do
        insurance.verification_result = {
          "coverage" => {
            "plan_year_start" => "2025-07-01",
            "deductible" => { "amount" => 500.0, "met" => 0 }
          }
        }
        insurance.save!
      end

      it 'calculates next reset date from plan year start' do
        travel_to Date.new(2025, 11, 30) do
          result = DaybreakHealthBackendSchema.execute(
            query,
            variables: { sessionId: onboarding_session.id },
            context: context
          )

          data = result['data']['deductibleStatus']
          # Next reset should be 2026-07-01
          expect(Date.parse(data['yearResetDate'])).to eq(Date.new(2026, 7, 1))
        end
      end
    end

    context 'without plan year start date' do
      before do
        insurance.verification_result = {
          "coverage" => {
            "deductible" => { "amount" => 500.0, "met" => 0 }
          }
        }
        insurance.save!
      end

      it 'defaults to next January 1' do
        travel_to Date.new(2025, 11, 30) do
          result = DaybreakHealthBackendSchema.execute(
            query,
            variables: { sessionId: onboarding_session.id },
            context: context
          )

          data = result['data']['deductibleStatus']
          # Should default to next January 1
          expect(Date.parse(data['yearResetDate'])).to eq(Date.new(2026, 1, 1))
        end
      end
    end
  end
end
