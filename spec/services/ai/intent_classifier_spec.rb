# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::IntentClassifier do
  describe '.call' do
    context 'with help request patterns' do
      it 'detects "I don\'t understand" as help_request' do
        result = described_class.call(
          message: "I don't understand what you're asking",
          context: {}
        )

        expect(result[:intent]).to eq(:help_request)
        expect(result[:confidence]).to be >= 0.8
        expect(result[:pattern]).to include("don't understand")
      end

      it 'detects "What does X mean" as help_request' do
        result = described_class.call(
          message: "What does SSN mean?",
          context: {}
        )

        expect(result[:intent]).to eq(:help_request)
        expect(result[:confidence]).to be >= 0.8
      end

      it 'detects "Why are you asking" as help_request' do
        result = described_class.call(
          message: "Why are you asking for my email?",
          context: {}
        )

        expect(result[:intent]).to eq(:help_request)
        expect(result[:confidence]).to be >= 0.8
      end

      it 'detects "Why do you need" as help_request' do
        result = described_class.call(
          message: "Why do you need this information?",
          context: {}
        )

        expect(result[:intent]).to eq(:help_request)
        expect(result[:confidence]).to be >= 0.8
      end

      it 'detects "help" keyword as help_request' do
        result = described_class.call(
          message: "I need help with this",
          context: {}
        )

        expect(result[:intent]).to eq(:help_request)
        expect(result[:confidence]).to be >= 0.8
      end

      it 'detects "confused" as help_request' do
        result = described_class.call(
          message: "I'm confused about this question",
          context: {}
        )

        expect(result[:intent]).to eq(:help_request)
        expect(result[:confidence]).to be >= 0.8
      end
    end

    context 'with clarification patterns' do
      it 'detects "Can you explain" as clarification' do
        result = described_class.call(
          message: "Can you explain what you mean?",
          context: {}
        )

        expect(result[:intent]).to eq(:clarification)
        expect(result[:confidence]).to be >= 0.8
      end

      it 'detects "Could you clarify" as clarification' do
        result = described_class.call(
          message: "Could you clarify that question?",
          context: {}
        )

        expect(result[:intent]).to eq(:clarification)
        expect(result[:confidence]).to be >= 0.8
      end

      it 'detects "What exactly" as clarification' do
        result = described_class.call(
          message: "What exactly are you asking for?",
          context: {}
        )

        expect(result[:intent]).to eq(:clarification)
        expect(result[:confidence]).to be >= 0.8
      end
    end

    context 'with off-topic patterns' do
      it 'detects cost questions as off_topic' do
        result = described_class.call(
          message: "How much does this cost?",
          context: {}
        )

        expect(result[:intent]).to eq(:off_topic)
        expect(result[:confidence]).to be >= 0.8
      end

      it 'detects service hours questions as off_topic' do
        result = described_class.call(
          message: "What are your hours?",
          context: {}
        )

        expect(result[:intent]).to eq(:off_topic)
        expect(result[:confidence]).to be >= 0.8
      end

      it 'detects location questions as off_topic' do
        result = described_class.call(
          message: "Where are you located?",
          context: {}
        )

        expect(result[:intent]).to eq(:off_topic)
        expect(result[:confidence]).to be >= 0.8
      end
    end

    context 'with question patterns' do
      it 'detects question with question mark' do
        result = described_class.call(
          message: "What happens next?",
          context: {}
        )

        expect(result[:intent]).to eq(:question)
        expect(result[:confidence]).to be >= 0.7
      end

      it 'detects question starting with question word' do
        result = described_class.call(
          message: "How long will this take",
          context: {}
        )

        # This might be classified as off_topic due to keyword match
        # or as question due to question pattern
        expect([:question, :off_topic]).to include(result[:intent])
      end
    end

    context 'with answer patterns' do
      it 'detects email as answer' do
        result = described_class.call(
          message: "sarah@email.com",
          context: { last_question: "What's your email?" }
        )

        expect(result[:intent]).to eq(:answer)
        expect(result[:confidence]).to be >= 0.5
      end

      it 'detects phone number as answer' do
        result = described_class.call(
          message: "555-123-4567",
          context: { last_question: "What's your phone?" }
        )

        expect(result[:intent]).to eq(:answer)
        expect(result[:confidence]).to be >= 0.5
      end

      it 'detects name as answer' do
        result = described_class.call(
          message: "Sarah Johnson",
          context: { last_question: "What's your name?" }
        )

        expect(result[:intent]).to eq(:answer)
        expect(result[:confidence]).to be >= 0.5
      end

      it 'detects age as answer' do
        result = described_class.call(
          message: "12 years old",
          context: { collecting_field: "child_age" }
        )

        expect(result[:intent]).to eq(:answer)
        expect(result[:confidence]).to be >= 0.5
      end

      it 'uses context to identify answer' do
        result = described_class.call(
          message: "John",
          context: { missing_fields: ["parent_first_name"] }
        )

        expect(result[:intent]).to eq(:answer)
        expect(result[:confidence]).to be > 0.5
      end
    end

    context 'with edge cases' do
      it 'handles empty message' do
        result = described_class.call(
          message: "",
          context: {}
        )

        expect(result[:intent]).to eq(:answer)
        expect(result[:confidence]).to eq(0.0)
      end

      it 'handles nil message' do
        result = described_class.call(
          message: nil,
          context: {}
        )

        expect(result[:intent]).to eq(:answer)
        expect(result[:confidence]).to eq(0.0)
      end

      it 'handles whitespace-only message' do
        result = described_class.call(
          message: "   ",
          context: {}
        )

        expect(result[:intent]).to eq(:answer)
        expect(result[:confidence]).to eq(0.0)
      end

      it 'detects uncertainty in short messages as help_request' do
        result = described_class.call(
          message: "Not sure",
          context: {}
        )

        expect(result[:intent]).to eq(:help_request)
        expect(result[:confidence]).to be >= 0.7
      end
    end

    context 'with context awareness' do
      it 'uses last_question context to classify as answer' do
        result = described_class.call(
          message: "42",
          context: { last_question: "How old is your child?" }
        )

        expect(result[:intent]).to eq(:answer)
      end

      it 'uses collecting_field context to classify as answer' do
        result = described_class.call(
          message: "Emily",
          context: { collecting_field: "child_first_name" }
        )

        expect(result[:intent]).to eq(:answer)
      end

      it 'uses missing_fields context to classify as answer' do
        result = described_class.call(
          message: "Yes, I can be reached at this number",
          context: { missing_fields: ["parent_phone"] }
        )

        expect(result[:intent]).to eq(:answer)
      end
    end

    context 'with confidence scoring' do
      it 'returns high confidence for keyword matches' do
        result = described_class.call(
          message: "I don't understand",
          context: {}
        )

        expect(result[:confidence]).to be >= 0.8
      end

      it 'returns medium confidence for heuristic matches' do
        result = described_class.call(
          message: "Maybe I think probably",
          context: {}
        )

        expect(result[:confidence]).to be >= 0.5
        expect(result[:confidence]).to be < 0.8
      end

      it 'includes detected_method in result' do
        result = described_class.call(
          message: "I don't understand",
          context: {}
        )

        expect(result[:detected_method]).to be_present
        expect([:keyword, :heuristic, :default]).to include(result[:detected_method].to_sym)
      end
    end

    context 'AC1: Recognizes question vs. answer intent' do
      it 'correctly distinguishes question from answer' do
        # Question
        question_result = described_class.call(
          message: "What does this mean?",
          context: {}
        )
        expect([:question, :help_request, :clarification]).to include(question_result[:intent])

        # Answer
        answer_result = described_class.call(
          message: "Sarah Johnson",
          context: { last_question: "What's your name?" }
        )
        expect(answer_result[:intent]).to eq(:answer)
      end
    end

    context 'AC6: Handles various help intent patterns' do
      help_patterns = [
        "I don't understand",
        "What does X mean",
        "Why are you asking",
        "I need help",
        "I'm confused"
      ]

      help_patterns.each do |pattern|
        it "detects '#{pattern}' as help request" do
          result = described_class.call(
            message: pattern,
            context: {}
          )

          expect([:help_request, :clarification, :question]).to include(result[:intent])
        end
      end
    end
  end
end
