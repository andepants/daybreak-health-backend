# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sessions::ProgressMerger do
  let(:session) { create(:onboarding_session, progress: existing_progress) }
  let(:merger) { described_class.new(session, new_progress) }

  describe '#call' do
    context 'with empty existing progress' do
      let(:existing_progress) { {} }
      let(:new_progress) { { 'currentStep' => 'parent_info', 'completedSteps' => ['welcome'] } }

      it 'returns the new progress' do
        result = merger.call
        expect(result).to eq(new_progress)
      end
    end

    context 'with existing progress' do
      let(:existing_progress) do
        {
          'currentStep' => 'welcome',
          'completedSteps' => ['welcome'],
          'intake' => { 'parentInfoComplete' => false }
        }
      end

      context 'when updating currentStep' do
        let(:new_progress) { { 'currentStep' => 'parent_info' } }

        it 'updates currentStep to new value' do
          result = merger.call
          expect(result['currentStep']).to eq('parent_info')
        end

        it 'preserves other fields' do
          result = merger.call
          expect(result['completedSteps']).to eq(['welcome'])
          expect(result['intake']).to eq({ 'parentInfoComplete' => false })
        end
      end

      context 'when adding to completedSteps' do
        let(:new_progress) { { 'completedSteps' => ['terms', 'privacy'] } }

        it 'merges arrays and removes duplicates' do
          result = merger.call
          expect(result['completedSteps']).to contain_exactly('welcome', 'terms', 'privacy')
        end
      end

      context 'when completedSteps has duplicates' do
        let(:new_progress) { { 'completedSteps' => ['welcome', 'terms'] } }

        it 'deduplicates the array' do
          result = merger.call
          expect(result['completedSteps']).to contain_exactly('welcome', 'terms')
        end
      end

      context 'with deep nested objects' do
        let(:existing_progress) do
          {
            'intake' => {
              'parentInfo' => { 'status' => 'pending' },
              'childInfo' => { 'status' => 'not_started' }
            }
          }
        end
        let(:new_progress) do
          {
            'intake' => {
              'parentInfo' => { 'status' => 'complete' }
            }
          }
        end

        it 'deep merges nested hashes' do
          result = merger.call
          expect(result['intake']['parentInfo']['status']).to eq('complete')
          expect(result['intake']['childInfo']['status']).to eq('not_started')
        end
      end

      context 'with null values' do
        let(:new_progress) { { 'currentStep' => nil } }

        it 'allows null values to override' do
          result = merger.call
          expect(result['currentStep']).to be_nil
        end
      end

      context 'with complex merge scenario' do
        let(:existing_progress) do
          {
            'currentStep' => 'parent_info',
            'completedSteps' => ['welcome', 'terms'],
            'intake' => {
              'parentInfoComplete' => true,
              'childInfoComplete' => false
            },
            'insurance' => {
              'cardUploaded' => false
            }
          }
        end
        let(:new_progress) do
          {
            'currentStep' => 'child_info',
            'completedSteps' => ['parent_info'],
            'intake' => {
              'childInfoComplete' => true
            },
            'assessment' => {
              'screeningComplete' => false
            }
          }
        end

        it 'merges all sections correctly' do
          result = merger.call

          expect(result['currentStep']).to eq('child_info')
          expect(result['completedSteps']).to contain_exactly('welcome', 'terms', 'parent_info')
          expect(result['intake']['parentInfoComplete']).to be true
          expect(result['intake']['childInfoComplete']).to be true
          expect(result['insurance']['cardUploaded']).to be false
          expect(result['assessment']['screeningComplete']).to be false
        end
      end
    end
  end
end
