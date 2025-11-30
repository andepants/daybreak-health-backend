# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Conversation::ProgressService do
  let(:session) { create(:onboarding_session) }
  let(:service) { described_class.new(session) }

  describe '#calculate' do
    context 'with empty progress' do
      before { session.update!(progress: {}) }

      it 'returns initial progress state' do
        result = service.calculate

        expect(result[:percentage]).to eq(0)
        expect(result[:current_phase]).to eq('welcome')
        expect(result[:completed_phases]).to eq([])
        expect(result[:next_phase]).to eq('parent_info')
        expect(result[:estimated_minutes_remaining]).to be > 0
      end
    end

    context 'AC1: Progress percentage calculation' do
      it 'calculates percentage from completed vs required fields' do
        # Set up partial completion: 3 parent fields (out of 6 total parent fields)
        session.update!(progress: {
          'currentStep' => 'parent_info',
          'completedSteps' => ['welcome'],
          'intake' => {
            'parent' => {
              'firstName' => 'John',
              'lastName' => 'Doe',
              'email' => 'john@example.com'
            }
          }
        })

        result = service.calculate
        # 3 fields out of 14 total (6 parent + 4 child + 1 concerns + 3 insurance) = 21%
        expect(result[:percentage]).to be_between(20, 25)
      end

      it 'returns 100% when all required fields are completed' do
        session.update!(progress: {
          'currentStep' => 'assessment',
          'completedSteps' => ['welcome', 'parent_info', 'child_info', 'concerns', 'insurance'],
          'intake' => {
            'parentInfoComplete' => true,
            'childInfoComplete' => true,
            'concerns' => { 'primaryConcerns' => 'anxiety' }
          },
          'insurance' => {
            'selfPay' => true
          },
          'assessment' => {
            'screeningComplete' => true
          }
        })

        result = service.calculate
        expect(result[:percentage]).to eq(100)
      end
    end

    context 'AC2: Current phase display' do
      it 'displays current phase from currentStep' do
        session.update!(progress: { 'currentStep' => 'child_info' })

        result = service.calculate
        expect(result[:current_phase]).to eq('child_info')
      end

      it 'normalizes various phase name formats' do
        session.update!(progress: { 'currentStep' => 'childInfo' })

        result = service.calculate
        expect(result[:current_phase]).to eq('child_info')
      end

      it 'defaults to welcome when currentStep is blank' do
        session.update!(progress: { 'currentStep' => '' })

        result = service.calculate
        expect(result[:current_phase]).to eq('welcome')
      end
    end

    context 'AC3: Time estimation from averages' do
      it 'estimates time based on remaining phases' do
        session.update!(progress: {
          'currentStep' => 'parent_info',
          'completedSteps' => ['welcome']
        })

        result = service.calculate
        # Remaining: child_info(3) + concerns(2) + insurance(4) + assessment(5) = 14 min
        expect(result[:estimated_minutes_remaining]).to eq(14)
      end

      it 'returns 0 when all phases are complete' do
        session.update!(progress: {
          'currentStep' => 'assessment',
          'completedSteps' => ['welcome', 'parent_info', 'child_info', 'concerns', 'insurance', 'assessment']
        })

        result = service.calculate
        expect(result[:estimated_minutes_remaining]).to eq(0)
      end
    end

    context 'AC4: Completed phases display' do
      it 'returns array of completed phase names' do
        session.update!(progress: {
          'currentStep' => 'insurance',
          'completedSteps' => ['welcome', 'parent_info', 'child_info', 'concerns']
        })

        result = service.calculate
        expect(result[:completed_phases]).to match_array(['welcome', 'parent_info', 'child_info', 'concerns'])
      end

      it 'removes duplicates from completed steps' do
        session.update!(progress: {
          'completedSteps' => ['welcome', 'parent_info', 'welcome']
        })

        result = service.calculate
        expect(result[:completed_phases]).to match_array(['welcome', 'parent_info'])
      end
    end

    context 'AC5: Next phase preview' do
      it 'returns next phase in sequence' do
        session.update!(progress: { 'currentStep' => 'parent_info' })

        result = service.calculate
        expect(result[:next_phase]).to eq('child_info')
      end

      it 'returns nil when at last phase' do
        session.update!(progress: { 'currentStep' => 'assessment' })

        result = service.calculate
        expect(result[:next_phase]).to be_nil
      end
    end

    context 'AC7: Monotonic progress (no backward movement)' do
      it 'never decreases percentage' do
        # Start at 50%
        session.update!(progress: {
          'currentStep' => 'insurance',
          'completedSteps' => ['welcome', 'parent_info', 'child_info'],
          'last_percentage' => 50,
          'intake' => {
            'parentInfoComplete' => true,
            'childInfoComplete' => true
          }
        })

        result = service.calculate
        initial_percentage = result[:percentage]
        expect(initial_percentage).to be >= 50

        # Simulate removing some data (should not decrease percentage)
        session.update!(progress: {
          'currentStep' => 'insurance',
          'completedSteps' => ['welcome', 'parent_info'],
          'last_percentage' => initial_percentage,
          'intake' => {
            'parentInfoComplete' => true
          }
        })

        result = service.calculate
        expect(result[:percentage]).to be >= initial_percentage
      end
    end

    context 'AC8: Adaptive time estimation' do
      it 'adjusts estimate based on actual completion times' do
        # User is taking twice as long as baseline
        session.update!(progress: {
          'currentStep' => 'child_info',
          'completedSteps' => ['welcome', 'parent_info'],
          'phaseTimings' => {
            'welcome' => {
              'started_at' => 10.minutes.ago.iso8601,
              'completed_at' => 8.minutes.ago.iso8601
            },
            'parent_info' => {
              'started_at' => 8.minutes.ago.iso8601,
              'completed_at' => 4.minutes.ago.iso8601
            }
          }
        })

        result = service.calculate
        # Baseline for remaining: concerns(2) + insurance(4) + assessment(5) = 11 min
        # With 2x pace multiplier: ~22 min (capped at 2.0x)
        expect(result[:estimated_minutes_remaining]).to be >= 20
      end

      it 'bounds pace multiplier between 0.5x and 2.0x' do
        # Simulate very slow user (would be 10x without bounds)
        session.update!(progress: {
          'currentStep' => 'child_info',
          'phaseTimings' => {
            'parent_info' => {
              'started_at' => 30.minutes.ago.iso8601,
              'completed_at' => 10.minutes.ago.iso8601 # 20 min for 2-min baseline
            }
          }
        })

        result = service.calculate
        # Should be capped at 2.0x multiplier
        baseline = 2 + 4 + 5 # concerns + insurance + assessment
        expect(result[:estimated_minutes_remaining]).to be <= (baseline * 2.0)
      end
    end

    context 'caching behavior' do
      before do
        Rails.cache.clear
        session.update!(progress: { 'currentStep' => 'parent_info' })
      end

      it 'caches calculated progress' do
        # First call - should calculate and cache
        result1 = service.calculate

        # Second call - should hit cache
        expect(Rails.cache).to receive(:read).and_call_original
        result2 = service.calculate

        expect(result1).to eq(result2)
      end

      it 'falls back to calculation if cache fails' do
        allow(Rails.cache).to receive(:read).and_raise(StandardError)

        expect { service.calculate }.not_to raise_error
        result = service.calculate
        expect(result[:percentage]).to be >= 0
      end
    end

    describe '.invalidate_cache' do
      it 'calls Rails.cache.delete with correct key' do
        cache_key = "daybreak:progress:#{session.id}"

        expect(Rails.cache).to receive(:delete).with(cache_key)

        described_class.invalidate_cache(session)
      end
    end
  end

  describe 'edge cases' do
    it 'handles nil progress gracefully' do
      session.update!(progress: nil)

      result = service.calculate
      expect(result[:percentage]).to eq(0)
      expect(result[:current_phase]).to eq('welcome')
    end

    it 'handles corrupted progress JSONB' do
      session.update!(progress: { 'invalid' => 'data' })

      expect { service.calculate }.not_to raise_error
      result = service.calculate
      expect(result[:percentage]).to eq(0)
    end

    it 'handles missing phaseTimings gracefully' do
      session.update!(progress: {
        'currentStep' => 'insurance',
        'phaseTimings' => nil
      })

      result = service.calculate
      expect(result[:estimated_minutes_remaining]).to be > 0
    end
  end
end
