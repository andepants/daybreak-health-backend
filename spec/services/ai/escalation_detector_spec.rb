# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::EscalationDetector do
  let(:detector) { described_class.new }

  describe '#detect_escalation_intent' do
    context 'with escalation trigger phrases' do
      # AC 3.5.8: Test all documented trigger phrases
      it 'detects "speak to human"' do
        result = detector.detect_escalation_intent('I want to speak to human')
        expect(result[:escalation_detected]).to be true
        expect(result[:matched_phrases]).to include('speak to human')
      end

      it 'detects "talk to person"' do
        result = detector.detect_escalation_intent('Can I talk to person?')
        expect(result[:escalation_detected]).to be true
        expect(result[:matched_phrases]).to include('talk to person')
      end

      it 'detects "real person"' do
        result = detector.detect_escalation_intent('I need a real person')
        expect(result[:escalation_detected]).to be true
        expect(result[:matched_phrases]).to include('real person')
      end

      it 'detects "not a bot"' do
        result = detector.detect_escalation_intent("You're not a bot, right?")
        expect(result[:escalation_detected]).to be true
        expect(result[:matched_phrases]).to include('not a bot')
      end

      it 'detects "representative"' do
        result = detector.detect_escalation_intent('Can I speak with a representative?')
        expect(result[:escalation_detected]).to be true
        expect(result[:matched_phrases]).to include('representative')
      end

      it 'detects "actual person"' do
        result = detector.detect_escalation_intent('I want to talk to an actual person')
        expect(result[:escalation_detected]).to be true
        expect(result[:matched_phrases]).to include('actual person')
      end

      it 'detects "human help"' do
        result = detector.detect_escalation_intent('I need human help')
        expect(result[:escalation_detected]).to be true
        expect(result[:matched_phrases]).to include('human help')
      end

      it 'detects "speak to someone"' do
        result = detector.detect_escalation_intent('Can I speak to someone?')
        expect(result[:escalation_detected]).to be true
        expect(result[:matched_phrases]).to include('speak to someone')
      end
    end

    context 'with case-insensitive matching' do
      # AC 3.5.8: Case-insensitive matching
      it 'detects uppercase phrases' do
        result = detector.detect_escalation_intent('I WANT TO TALK TO A REAL PERSON')
        expect(result[:escalation_detected]).to be true
      end

      it 'detects mixed case phrases' do
        result = detector.detect_escalation_intent('Can I SpEaK To A HuMaN?')
        expect(result[:escalation_detected]).to be true
      end

      it 'detects title case phrases' do
        result = detector.detect_escalation_intent('Please Let Me Talk To Someone')
        expect(result[:escalation_detected]).to be true
      end
    end

    context 'with multiple matched phrases' do
      it 'detects multiple triggers in one message' do
        message = 'I need to speak to a real person, not a bot. Is there a representative?'
        result = detector.detect_escalation_intent(message)

        expect(result[:escalation_detected]).to be true
        expect(result[:matched_phrases]).to include('real person', 'not a bot', 'representative')
      end

      it 'returns all matched phrases' do
        message = 'I want human help from an actual person'
        result = detector.detect_escalation_intent(message)

        expect(result[:escalation_detected]).to be true
        expect(result[:matched_phrases]).to include('human help', 'actual person')
      end
    end

    context 'with variations and flexible matching' do
      it 'detects phrases with extra words in between' do
        result = detector.detect_escalation_intent('Can I talk to a real live person please?')
        expect(result[:escalation_detected]).to be true
      end

      it 'detects phrases at start of message' do
        result = detector.detect_escalation_intent('Speak to human - I need help now')
        expect(result[:escalation_detected]).to be true
      end

      it 'detects phrases at end of message' do
        result = detector.detect_escalation_intent("This isn't working, I want to talk to someone")
        expect(result[:escalation_detected]).to be true
      end

      it 'detects phrases in middle of longer message' do
        message = "I've been trying to answer these questions but I really need to " \
                  'speak to a real person who can help me understand what I need to do'
        result = detector.detect_escalation_intent(message)
        expect(result[:escalation_detected]).to be true
      end
    end

    context 'with non-escalation phrases' do
      # AC 3.5.8: Should NOT trigger on contextually different uses of similar words
      it 'does not detect "my child needs a human therapist"' do
        result = detector.detect_escalation_intent('My child needs a human therapist')
        expect(result[:escalation_detected]).to be false
      end

      it 'does not detect "tell me about the humans on your team"' do
        result = detector.detect_escalation_intent('Tell me about the humans on your team')
        expect(result[:escalation_detected]).to be false
      end

      it 'does not detect general questions' do
        result = detector.detect_escalation_intent('What services do you provide?')
        expect(result[:escalation_detected]).to be false
      end

      it 'does not detect normal conversation' do
        result = detector.detect_escalation_intent('My child is 8 years old and needs help')
        expect(result[:escalation_detected]).to be false
      end

      it 'does not detect "person" in other contexts' do
        result = detector.detect_escalation_intent('My child is a very active person')
        expect(result[:escalation_detected]).to be false
      end
    end

    context 'with edge cases' do
      it 'handles empty string' do
        result = detector.detect_escalation_intent('')
        expect(result[:escalation_detected]).to be false
        expect(result[:matched_phrases]).to be_empty
      end

      it 'handles nil input' do
        result = detector.detect_escalation_intent(nil)
        expect(result[:escalation_detected]).to be false
        expect(result[:matched_phrases]).to be_empty
      end

      it 'handles whitespace only' do
        result = detector.detect_escalation_intent('   ')
        expect(result[:escalation_detected]).to be false
        expect(result[:matched_phrases]).to be_empty
      end

      it 'handles very long messages' do
        long_message = 'word ' * 1000 + ' I need to speak to a real person ' + 'word ' * 1000
        result = detector.detect_escalation_intent(long_message)
        expect(result[:escalation_detected]).to be true
      end
    end

    context 'return value structure' do
      it 'returns hash with escalation_detected key' do
        result = detector.detect_escalation_intent('test')
        expect(result).to have_key(:escalation_detected)
      end

      it 'returns hash with matched_phrases key' do
        result = detector.detect_escalation_intent('test')
        expect(result).to have_key(:matched_phrases)
      end

      it 'matched_phrases is an array' do
        result = detector.detect_escalation_intent('I need help')
        expect(result[:matched_phrases]).to be_an(Array)
      end

      it 'escalation_detected is a boolean' do
        result = detector.detect_escalation_intent('I need help')
        expect(result[:escalation_detected]).to be_in([true, false])
      end
    end
  end

  describe '#escalation_detected?' do
    it 'returns true when escalation detected' do
      expect(detector.escalation_detected?('I want to speak to a human')).to be true
    end

    it 'returns false when no escalation detected' do
      expect(detector.escalation_detected?('What services do you offer?')).to be false
    end

    it 'is a convenience wrapper around detect_escalation_intent' do
      message = 'talk to a real person'
      full_result = detector.detect_escalation_intent(message)
      boolean_result = detector.escalation_detected?(message)

      expect(boolean_result).to eq(full_result[:escalation_detected])
    end
  end

  describe 'performance' do
    # AC 3.5: Escalation detection should not add >100ms to message processing
    it 'completes detection in under 100ms for typical messages' do
      messages = [
        'I want to speak to a human',
        'My child is 8 years old',
        'Can I talk to someone about this?',
        'What are your hours?',
        'I need a real person to help me',
        'This is very confusing'
      ]

      start_time = Time.now
      messages.each { |msg| detector.detect_escalation_intent(msg) }
      end_time = Time.now

      average_time_ms = ((end_time - start_time) / messages.size) * 1000
      expect(average_time_ms).to be < 100
    end

    it 'handles concurrent requests efficiently' do
      threads = 10.times.map do
        Thread.new do
          100.times { detector.detect_escalation_intent('I need to talk to someone') }
        end
      end

      start_time = Time.now
      threads.each(&:join)
      end_time = Time.now

      total_time_s = end_time - start_time
      # Should complete 1000 detections in under 1 second
      expect(total_time_s).to be < 1.0
    end
  end
end
