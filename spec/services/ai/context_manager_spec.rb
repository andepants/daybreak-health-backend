# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::ContextManager, type: :service do
  let(:session) { create(:onboarding_session, progress: initial_progress) }
  let(:initial_progress) { {} }
  let(:context_manager) { described_class.new(session_id: session.id) }

  describe '#initialize' do
    it 'initializes with default state when no progress exists' do
      expect(context_manager.current_phase).to eq('welcome')
      expect(context_manager.collected_fields).to eq([])
      expect(context_manager.pending_questions).to eq([])
    end

    context 'with existing progress' do
      let(:initial_progress) do
        {
          'context_manager' => {
            'phase' => 'parent_info',
            'collected_fields' => ['parent_first_name'],
            'pending_questions' => ['What is your email?'],
            'field_metadata' => {
              'parent_first_name' => {
                'collected_at' => '2025-11-29T10:00:00Z',
                'confidence' => 'high'
              }
            }
          }
        }
      end

      it 'loads existing state from session progress' do
        expect(context_manager.current_phase).to eq('parent_info')
        expect(context_manager.collected_fields).to eq(['parent_first_name'])
        expect(context_manager.pending_questions).to eq(['What is your email?'])
      end
    end
  end

  describe '#mark_field_collected' do
    it 'marks a field as collected with high confidence by default' do
      context_manager.mark_field_collected('parent_email')

      expect(context_manager.collected_fields).to include('parent_email')
      expect(context_manager.field_collected?('parent_email')).to be true
    end

    it 'stores field metadata with timestamp and confidence' do
      freeze_time do
        context_manager.mark_field_collected('parent_email', confidence: 'medium')

        session.reload
        metadata = session.progress.dig('context_manager', 'field_metadata', 'parent_email')

        expect(metadata['confidence']).to eq('medium')
        expect(metadata['collected_at']).to eq(Time.current.iso8601)
      end
    end

    it 'does not duplicate fields when marked multiple times' do
      context_manager.mark_field_collected('parent_email')
      context_manager.mark_field_collected('parent_email')

      expect(context_manager.collected_fields.count('parent_email')).to eq(1)
    end

    it 'persists state to session progress' do
      context_manager.mark_field_collected('parent_email')

      session.reload
      expect(session.progress.dig('context_manager', 'collected_fields')).to include('parent_email')
    end
  end

  describe '#can_transition_phase?' do
    context 'in welcome phase' do
      it 'can transition immediately (no required fields)' do
        expect(context_manager.can_transition_phase?).to be true
      end
    end

    context 'in parent_info phase' do
      let(:initial_progress) do
        {
          'context_manager' => {
            'phase' => 'parent_info',
            'collected_fields' => [],
            'pending_questions' => [],
            'field_metadata' => {}
          }
        }
      end

      it 'cannot transition without required fields' do
        expect(context_manager.can_transition_phase?).to be false
      end

      it 'can transition when all required fields collected' do
        context_manager.mark_field_collected('parent_first_name')
        context_manager.mark_field_collected('parent_email')

        expect(context_manager.can_transition_phase?).to be true
      end
    end
  end

  describe '#transition_to_next_phase' do
    it 'transitions from welcome to parent_info' do
      expect(context_manager.current_phase).to eq('welcome')

      context_manager.transition_to_next_phase

      expect(context_manager.current_phase).to eq('parent_info')
    end

    it 'transitions through all phases in order' do
      # Welcome -> Parent Info (no requirements)
      context_manager.transition_to_next_phase
      expect(context_manager.current_phase).to eq('parent_info')

      # Parent Info -> Child Info (requires parent fields)
      context_manager.mark_field_collected('parent_first_name')
      context_manager.mark_field_collected('parent_email')
      context_manager.transition_to_next_phase
      expect(context_manager.current_phase).to eq('child_info')

      # Child Info -> Concerns (requires child fields)
      context_manager.mark_field_collected('child_first_name')
      context_manager.mark_field_collected('child_last_name')
      context_manager.mark_field_collected('child_date_of_birth')
      context_manager.transition_to_next_phase
      expect(context_manager.current_phase).to eq('concerns')
    end
  end

  describe '#calculate_progress_percentage' do
    it 'returns 0% when no fields collected' do
      expect(context_manager.calculate_progress_percentage).to eq(0)
    end

    it 'calculates percentage based on collected vs total required fields' do
      context_manager.mark_field_collected('parent_first_name')
      context_manager.mark_field_collected('parent_email')

      # 2 out of 6 total fields = 33%
      expect(context_manager.calculate_progress_percentage).to eq(33)
    end
  end

  describe '#analyze_response' do
    it 'detects complete responses' do
      analysis = context_manager.analyze_response('My name is Sarah Johnson')

      expect(analysis[:is_complete]).to be true
      expect(analysis[:is_ambiguous]).to be false
    end

    it 'detects ambiguous responses' do
      analysis = context_manager.analyze_response("I'm not sure, maybe...")

      expect(analysis[:is_ambiguous]).to be true
      expect(analysis[:needs_clarification]).to be true
    end
  end
end
