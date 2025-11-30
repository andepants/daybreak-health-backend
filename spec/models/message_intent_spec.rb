# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message, type: :model do
  let(:session) { create(:onboarding_session) }
  let(:message) { create(:message, onboarding_session: session, role: :user) }

  describe 'Story 3.3: Intent tracking' do
    describe '#store_intent' do
      it 'stores intent classification result in metadata' do
        intent_result = {
          intent: :help_request,
          confidence: 0.95,
          pattern: "i don't understand",
          detected_method: 'keyword'
        }

        message.store_intent(intent_result)

        expect(message.metadata['intent']).to eq('help_request')
        expect(message.metadata['intent_confidence']).to eq(0.95)
        expect(message.metadata['intent_pattern']).to eq("i don't understand")
        expect(message.metadata['intent_method']).to eq('keyword')
        expect(message.metadata['classified_at']).to be_present
      end

      it 'initializes metadata if nil' do
        message.metadata = nil
        intent_result = { intent: :answer, confidence: 0.8, pattern: 'email', detected_method: 'heuristic' }

        message.store_intent(intent_result)

        expect(message.metadata).to be_a(Hash)
        expect(message.metadata['intent']).to eq('answer')
      end

      it 'persists intent data when saved' do
        intent_result = { intent: :off_topic, confidence: 0.85, pattern: 'cost', detected_method: 'keyword' }

        message.store_intent(intent_result)
        message.save!
        message.reload

        expect(message.metadata['intent']).to eq('off_topic')
        expect(message.metadata['intent_confidence']).to eq(0.85)
      end
    end

    describe '#intent' do
      it 'returns stored intent' do
        message.metadata = { 'intent' => 'help_request' }
        expect(message.intent).to eq('help_request')
      end

      it 'returns nil if no intent stored' do
        message.metadata = {}
        expect(message.intent).to be_nil
      end

      it 'returns nil if metadata is nil' do
        message.metadata = nil
        expect(message.intent).to be_nil
      end
    end

    describe '#intent_confidence' do
      it 'returns stored confidence' do
        message.metadata = { 'intent_confidence' => 0.92 }
        expect(message.intent_confidence).to eq(0.92)
      end

      it 'returns nil if no confidence stored' do
        message.metadata = {}
        expect(message.intent_confidence).to be_nil
      end
    end

    describe '#help_request?' do
      it 'returns true when intent is help_request' do
        message.metadata = { 'intent' => 'help_request' }
        expect(message.help_request?).to be true
      end

      it 'returns false when intent is not help_request' do
        message.metadata = { 'intent' => 'answer' }
        expect(message.help_request?).to be false
      end

      it 'returns false when no intent stored' do
        message.metadata = {}
        expect(message.help_request?).to be false
      end
    end

    describe '#off_topic?' do
      it 'returns true when intent is off_topic' do
        message.metadata = { 'intent' => 'off_topic' }
        expect(message.off_topic?).to be true
      end

      it 'returns false when intent is not off_topic' do
        message.metadata = { 'intent' => 'help_request' }
        expect(message.off_topic?).to be false
      end
    end

    describe '#question?' do
      it 'returns true when intent is question' do
        message.metadata = { 'intent' => 'question' }
        expect(message.question?).to be true
      end

      it 'returns false when intent is not question' do
        message.metadata = { 'intent' => 'answer' }
        expect(message.question?).to be false
      end
    end
  end
end
