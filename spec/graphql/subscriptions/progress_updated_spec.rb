# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscriptions::ProgressUpdated do
  let(:session) { create(:onboarding_session) }

  describe 'field structure' do
    it 'has all required fields' do
      expected_fields = %w[
        percentage
        currentPhase
        completedPhases
        nextPhase
        estimatedMinutesRemaining
      ]

      expect(described_class.fields.keys).to match_array(expected_fields)
    end

    it 'has correct field types' do
      expect(described_class.fields['percentage'].type.to_type_signature).to eq('Int!')
      expect(described_class.fields['currentPhase'].type.to_type_signature).to eq('String!')
      expect(described_class.fields['completedPhases'].type.to_type_signature).to eq('[String!]!')
      expect(described_class.fields['nextPhase'].type.to_type_signature).to eq('String')
      expect(described_class.fields['estimatedMinutesRemaining'].type.to_type_signature).to eq('Int!')
    end
  end

  describe 'integration with ProgressService' do
    it 'can calculate and return progress for a session' do
      session.update!(progress: {
        'currentStep' => 'parent_info',
        'completedSteps' => ['welcome']
      })

      progress_data = Conversation::ProgressService.new(session).calculate

      # Verify structure matches subscription fields
      expect(progress_data).to include(
        :percentage,
        :current_phase,
        :completed_phases,
        :next_phase,
        :estimated_minutes_remaining
      )

      expect(progress_data[:percentage]).to be_a(Integer)
      expect(progress_data[:current_phase]).to be_a(String)
      expect(progress_data[:completed_phases]).to be_an(Array)
      expect(progress_data[:estimated_minutes_remaining]).to be_a(Integer)
    end

    it 'handles complete progress data' do
      session.update!(progress: {
        'currentStep' => 'insurance',
        'completedSteps' => ['welcome', 'parent_info', 'child_info'],
        'intake' => {
          'parentInfoComplete' => true,
          'childInfoComplete' => true
        }
      })

      progress_data = Conversation::ProgressService.new(session).calculate

      expect(progress_data[:current_phase]).to eq('insurance')
      expect(progress_data[:completed_phases]).to include('welcome', 'parent_info', 'child_info')
      expect(progress_data[:next_phase]).to eq('assessment')
    end

    it 'handles final phase with nil nextPhase' do
      session.update!(progress: {
        'currentStep' => 'assessment',
        'completedSteps' => ONBOARDING_PHASE_ORDER.map(&:to_s)
      })

      progress_data = Conversation::ProgressService.new(session).calculate

      expect(progress_data[:next_phase]).to be_nil
    end
  end

  describe 'AC6: Real-time progress subscription' do
    it 'subscription is defined in GraphQL schema' do
      # Verify the subscription exists in the schema
      subscription_type = DaybreakHealthBackendSchema.subscription
      expect(subscription_type).to be_present
      expect(subscription_type.fields.keys).to include('progressUpdated')
    end

    it 'subscription trigger includes all required progress fields' do
      session.update!(progress: {
        'currentStep' => 'child_info',
        'completedSteps' => ['welcome', 'parent_info'],
        'phaseTimings' => {
          'parent_info' => {
            'started_at' => 5.minutes.ago.iso8601,
            'completed_at' => 1.minute.ago.iso8601
          }
        }
      })

      progress_data = Conversation::ProgressService.new(session).calculate

      # Verify all subscription fields are present
      expect(progress_data[:percentage]).to be_a(Integer)
      expect(progress_data[:current_phase]).to eq('child_info')
      expect(progress_data[:completed_phases]).to be_an(Array)
      expect(progress_data[:next_phase]).to eq('concerns')
      expect(progress_data[:estimated_minutes_remaining]).to be > 0
    end
  end
end
