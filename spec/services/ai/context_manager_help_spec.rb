# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::ContextManager, type: :service do
  let(:session) { create(:onboarding_session) }
  let(:context_manager) { described_class.new(session_id: session.id) }

  describe 'Story 3.3: Help & Off-Topic Handling' do
    describe '#conversation_state' do
      it 'defaults to intake state' do
        expect(context_manager.conversation_state).to eq('intake')
      end

      it 'returns current conversation state' do
        context_manager.enter_help_mode(field: 'email')
        expect(context_manager.conversation_state).to eq('help')
      end
    end

    describe '#enter_help_mode' do
      it 'sets conversation state to help' do
        context_manager.enter_help_mode(field: 'email', question: 'Why do you need this?')

        expect(context_manager.conversation_state).to eq('help')
      end

      it 'stores help context' do
        context_manager.enter_help_mode(field: 'email', question: 'Why do you need this?')

        help_context = context_manager.help_context
        expect(help_context).to be_present
        expect(help_context['field']).to eq('email')
        expect(help_context['question']).to eq('Why do you need this?')
        expect(help_context['entered_at']).to be_present
      end

      it 'persists state to session' do
        context_manager.enter_help_mode(field: 'phone')

        # Reload context manager from session
        new_context = described_class.new(session_id: session.id)
        expect(new_context.conversation_state).to eq('help')
        expect(new_context.help_context['field']).to eq('phone')
      end
    end

    describe '#enter_off_topic_mode' do
      it 'sets conversation state to off_topic' do
        context_manager.enter_off_topic_mode('cost_concern')

        expect(context_manager.conversation_state).to eq('off_topic')
      end

      it 'increments off_topic_count' do
        initial_count = context_manager.off_topic_count

        context_manager.enter_off_topic_mode('cost_concern')
        expect(context_manager.off_topic_count).to eq(initial_count + 1)

        context_manager.enter_off_topic_mode('timeline_concern')
        expect(context_manager.off_topic_count).to eq(initial_count + 2)
      end

      it 'tracks last off-topic topic and timestamp' do
        context_manager.enter_off_topic_mode('cost_concern')

        session.reload
        last_off_topic = session.progress.dig('context_manager', 'last_off_topic')
        expect(last_off_topic['topic']).to eq('cost_concern')
        expect(last_off_topic['timestamp']).to be_present
      end
    end

    describe '#return_to_intake_mode' do
      it 'returns conversation state to intake' do
        context_manager.enter_help_mode(field: 'email')
        expect(context_manager.conversation_state).to eq('help')

        context_manager.return_to_intake_mode
        expect(context_manager.conversation_state).to eq('intake')
      end

      it 'clears help context' do
        context_manager.enter_help_mode(field: 'email', question: 'Why?')
        expect(context_manager.help_context).to be_present

        context_manager.return_to_intake_mode
        expect(context_manager.help_context).to be_nil
      end

      it 'returns previous state' do
        context_manager.enter_help_mode(field: 'email')
        previous_state = context_manager.return_to_intake_mode

        expect(previous_state).to eq('help')
      end

      it 'persists return to intake' do
        context_manager.enter_off_topic_mode('cost_concern')
        context_manager.return_to_intake_mode

        # Reload context manager
        new_context = described_class.new(session_id: session.id)
        expect(new_context.conversation_state).to eq('intake')
      end
    end

    describe '#in_help_mode?' do
      it 'returns true when in help mode' do
        context_manager.enter_help_mode(field: 'email')
        expect(context_manager.in_help_mode?).to be true
      end

      it 'returns false when not in help mode' do
        expect(context_manager.in_help_mode?).to be false
      end

      it 'returns false after returning to intake' do
        context_manager.enter_help_mode(field: 'email')
        context_manager.return_to_intake_mode

        expect(context_manager.in_help_mode?).to be false
      end
    end

    describe '#in_off_topic_mode?' do
      it 'returns true when in off-topic mode' do
        context_manager.enter_off_topic_mode('cost_concern')
        expect(context_manager.in_off_topic_mode?).to be true
      end

      it 'returns false when not in off-topic mode' do
        expect(context_manager.in_off_topic_mode?).to be false
      end
    end

    describe '#help_context' do
      it 'returns nil when not in help mode' do
        expect(context_manager.help_context).to be_nil
      end

      it 'returns help context when in help mode' do
        context_manager.enter_help_mode(field: 'phone', question: 'What?')

        help_context = context_manager.help_context
        expect(help_context).to be_a(Hash)
        expect(help_context['field']).to eq('phone')
      end
    end

    describe '#off_topic_count' do
      it 'starts at 0' do
        expect(context_manager.off_topic_count).to eq(0)
      end

      it 'increments with each off-topic entry' do
        3.times { |i| context_manager.enter_off_topic_mode("topic_#{i}") }
        expect(context_manager.off_topic_count).to eq(3)
      end

      it 'persists across context manager instances' do
        context_manager.enter_off_topic_mode('cost')
        context_manager.enter_off_topic_mode('timeline')

        new_context = described_class.new(session_id: session.id)
        expect(new_context.off_topic_count).to eq(2)
      end
    end

    describe '#should_consider_escalation?' do
      it 'returns false when off-topic count is low' do
        context_manager.enter_off_topic_mode('cost')
        expect(context_manager.should_consider_escalation?).to be false
      end

      it 'returns true when off-topic count is 3 or more' do
        3.times { |i| context_manager.enter_off_topic_mode("topic_#{i}") }
        expect(context_manager.should_consider_escalation?).to be true
      end

      it 'returns true when off-topic count exceeds 3' do
        5.times { |i| context_manager.enter_off_topic_mode("topic_#{i}") }
        expect(context_manager.should_consider_escalation?).to be true
      end
    end

    context 'AC2: Clarifying questions answered with helpful context' do
      it 'tracks help mode with field context' do
        context_manager.enter_help_mode(field: 'date_of_birth', question: 'Why do you need this?')

        expect(context_manager.in_help_mode?).to be true
        expect(context_manager.help_context['field']).to eq('date_of_birth')
      end
    end

    context 'AC3: Off-topic responses gently redirected to intake' do
      it 'tracks off-topic state' do
        context_manager.enter_off_topic_mode('cost_concern')

        expect(context_manager.in_off_topic_mode?).to be true
      end

      it 'counts off-topic redirections for analytics' do
        context_manager.enter_off_topic_mode('cost')
        context_manager.return_to_intake_mode
        context_manager.enter_off_topic_mode('timeline')

        expect(context_manager.off_topic_count).to eq(2)
      end
    end

    context 'AC7: Conversation naturally returns to intake after addressing concerns' do
      it 'returns to intake from help mode' do
        context_manager.enter_help_mode(field: 'email')
        expect(context_manager.conversation_state).to eq('help')

        context_manager.return_to_intake_mode
        expect(context_manager.conversation_state).to eq('intake')
      end

      it 'returns to intake from off-topic mode' do
        context_manager.enter_off_topic_mode('cost')
        expect(context_manager.conversation_state).to eq('off_topic')

        context_manager.return_to_intake_mode
        expect(context_manager.conversation_state).to eq('intake')
      end

      it 'clears help context when returning to intake' do
        context_manager.enter_help_mode(field: 'phone', question: 'Why?')
        context_manager.return_to_intake_mode

        expect(context_manager.help_context).to be_nil
      end
    end

    context 'state persistence' do
      it 'persists help state across instances' do
        context_manager.enter_help_mode(field: 'email')
        session.reload

        new_manager = described_class.new(session_id: session.id)
        expect(new_manager.in_help_mode?).to be true
      end

      it 'persists off-topic count across instances' do
        context_manager.enter_off_topic_mode('cost')
        context_manager.enter_off_topic_mode('timeline')
        session.reload

        new_manager = described_class.new(session_id: session.id)
        expect(new_manager.off_topic_count).to eq(2)
      end

      it 'persists return to intake across instances' do
        context_manager.enter_help_mode(field: 'email')
        context_manager.return_to_intake_mode
        session.reload

        new_manager = described_class.new(session_id: session.id)
        expect(new_manager.conversation_state).to eq('intake')
      end
    end
  end
end
