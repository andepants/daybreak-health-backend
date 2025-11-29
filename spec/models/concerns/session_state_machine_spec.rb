# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionStateMachine do
  let(:session) { create(:onboarding_session, status: initial_status) }

  describe '#can_transition_to?' do
    context 'from started' do
      let(:initial_status) { :started }

      it 'allows transition to in_progress' do
        expect(session.can_transition_to?(:in_progress)).to be true
      end

      it 'allows transition to abandoned' do
        expect(session.can_transition_to?(:abandoned)).to be true
      end

      it 'allows transition to expired' do
        expect(session.can_transition_to?(:expired)).to be true
      end

      it 'disallows transition to insurance_pending' do
        expect(session.can_transition_to?(:insurance_pending)).to be false
      end

      it 'disallows transition to submitted' do
        expect(session.can_transition_to?(:submitted)).to be false
      end
    end

    context 'from in_progress' do
      let(:initial_status) { :in_progress }

      it 'allows transition to insurance_pending' do
        expect(session.can_transition_to?(:insurance_pending)).to be true
      end

      it 'allows transition to abandoned' do
        expect(session.can_transition_to?(:abandoned)).to be true
      end

      it 'allows transition to expired' do
        expect(session.can_transition_to?(:expired)).to be true
      end

      it 'disallows backward transition to started' do
        expect(session.can_transition_to?(:started)).to be false
      end

      it 'disallows forward jump to submitted' do
        expect(session.can_transition_to?(:submitted)).to be false
      end
    end

    context 'from insurance_pending' do
      let(:initial_status) { :insurance_pending }

      it 'allows transition to assessment_complete' do
        expect(session.can_transition_to?(:assessment_complete)).to be true
      end

      it 'allows transition to abandoned' do
        expect(session.can_transition_to?(:abandoned)).to be true
      end

      it 'allows transition to expired' do
        expect(session.can_transition_to?(:expired)).to be true
      end

      it 'disallows backward transition to in_progress' do
        expect(session.can_transition_to?(:in_progress)).to be false
      end
    end

    context 'from assessment_complete' do
      let(:initial_status) { :assessment_complete }

      it 'allows transition to submitted' do
        expect(session.can_transition_to?(:submitted)).to be true
      end

      it 'allows transition to abandoned' do
        expect(session.can_transition_to?(:abandoned)).to be true
      end

      it 'allows transition to expired' do
        expect(session.can_transition_to?(:expired)).to be true
      end

      it 'disallows backward transition' do
        expect(session.can_transition_to?(:insurance_pending)).to be false
      end
    end

    context 'from terminal states' do
      context 'abandoned' do
        let(:initial_status) { :abandoned }

        it 'disallows any transitions' do
          expect(session.can_transition_to?(:started)).to be false
          expect(session.can_transition_to?(:in_progress)).to be false
          expect(session.can_transition_to?(:submitted)).to be false
        end
      end

      context 'expired' do
        let(:initial_status) { :expired }

        it 'disallows any transitions' do
          expect(session.can_transition_to?(:started)).to be false
          expect(session.can_transition_to?(:in_progress)).to be false
        end
      end

      context 'submitted' do
        let(:initial_status) { :submitted }

        it 'disallows any transitions' do
          expect(session.can_transition_to?(:started)).to be false
          expect(session.can_transition_to?(:abandoned)).to be false
        end
      end
    end
  end

  describe '#auto_transition_on_progress_update' do
    context 'when status is started' do
      let(:initial_status) { :started }

      it 'transitions to in_progress' do
        session.auto_transition_on_progress_update
        expect(session.status).to eq('in_progress')
      end
    end

    context 'when status is not started' do
      let(:initial_status) { :in_progress }

      it 'does not change status' do
        session.auto_transition_on_progress_update
        expect(session.status).to eq('in_progress')
      end
    end
  end

  describe '#terminal_state?' do
    it 'returns true for abandoned' do
      session = build(:onboarding_session, status: :abandoned)
      expect(session.terminal_state?).to be true
    end

    it 'returns true for expired' do
      session = build(:onboarding_session, status: :expired)
      expect(session.terminal_state?).to be true
    end

    it 'returns true for submitted' do
      session = build(:onboarding_session, status: :submitted)
      expect(session.terminal_state?).to be true
    end

    it 'returns false for started' do
      session = build(:onboarding_session, status: :started)
      expect(session.terminal_state?).to be false
    end

    it 'returns false for in_progress' do
      session = build(:onboarding_session, status: :in_progress)
      expect(session.terminal_state?).to be false
    end
  end

  describe '#active?' do
    it 'returns true for non-terminal states' do
      session = build(:onboarding_session, status: :started)
      expect(session.active?).to be true
    end

    it 'returns false for terminal states' do
      session = build(:onboarding_session, status: :submitted)
      expect(session.active?).to be false
    end
  end

  describe 'validation on save' do
    context 'with valid transition' do
      let(:initial_status) { :started }

      it 'allows saving with valid transition' do
        session.status = :in_progress
        expect(session).to be_valid
        expect(session.save).to be true
      end
    end

    context 'with invalid transition' do
      let(:initial_status) { :in_progress }

      it 'prevents saving with invalid transition' do
        session.status = :started
        expect(session).not_to be_valid
        expect(session.errors[:status]).to include('cannot transition from in_progress to started')
      end
    end

    context 'with backward transition' do
      let(:initial_status) { :assessment_complete }

      it 'prevents backward transition' do
        session.status = :insurance_pending
        expect(session).not_to be_valid
      end
    end
  end
end
