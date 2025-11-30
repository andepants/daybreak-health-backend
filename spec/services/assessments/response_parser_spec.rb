# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Assessments::ResponseParser do
  describe '.parse' do
    context 'with clear Likert responses' do
      it 'parses "not at all" as 0' do
        result = described_class.parse('not at all')
        expect(result[:value]).to eq(0)
        expect(result[:confidence]).to eq(:high)
        expect(result[:ambiguous]).to be false
      end

      it 'parses "never" as 0' do
        result = described_class.parse('Never really')
        expect(result[:value]).to eq(0)
      end

      it 'parses "not really" as 0' do
        result = described_class.parse('not really an issue')
        expect(result[:value]).to eq(0)
      end

      it 'parses "several days" as 1' do
        result = described_class.parse('I would say several days')
        expect(result[:value]).to eq(1)
        expect(result[:confidence]).to eq(:high)
      end

      it 'parses "sometimes" as 1' do
        result = described_class.parse('Sometimes, yeah')
        expect(result[:value]).to eq(1)
      end

      it 'parses "more than half the days" as 2' do
        result = described_class.parse('more than half the days for sure')
        expect(result[:value]).to eq(2)
        expect(result[:confidence]).to eq(:high)
      end

      it 'parses "often" as 2' do
        result = described_class.parse('Pretty often, honestly')
        expect(result[:value]).to eq(2)
      end

      it 'parses "nearly every day" as 3' do
        result = described_class.parse('nearly every day')
        expect(result[:value]).to eq(3)
        expect(result[:confidence]).to eq(:high)
      end

      it 'parses "almost every day" as 3' do
        result = described_class.parse('almost every day honestly')
        expect(result[:value]).to eq(3)
      end

      it 'parses "all the time" as 3' do
        result = described_class.parse('All the time!')
        expect(result[:value]).to eq(3)
      end

      it 'parses "always" as 3' do
        result = described_class.parse('Always')
        expect(result[:value]).to eq(3)
      end
    end

    context 'with ambiguous responses' do
      it 'flags "not sure" as needing clarification' do
        result = described_class.parse("I'm not sure really")
        expect(result[:ambiguous]).to be true
        expect(result[:needs_clarification]).to be true
        expect(result[:value]).to be_nil
      end

      it 'flags "maybe" as needing clarification' do
        result = described_class.parse('Maybe sometimes?')
        expect(result[:ambiguous]).to be true
        expect(result[:needs_clarification]).to be true
      end

      it 'flags "it varies" as needing clarification' do
        result = described_class.parse('It varies a lot')
        expect(result[:ambiguous]).to be true
        expect(result[:needs_clarification]).to be true
      end

      it 'flags "kind of" as needing clarification' do
        result = described_class.parse('Kind of, I guess')
        expect(result[:ambiguous]).to be true
      end
    end

    context 'with empty or blank responses' do
      it 'returns nil for empty string' do
        result = described_class.parse('')
        expect(result[:value]).to be_nil
        expect(result[:ambiguous]).to be true
        expect(result[:error]).to eq('Empty response')
      end

      it 'returns nil for nil input' do
        result = described_class.parse(nil)
        expect(result[:value]).to be_nil
      end
    end

    context 'with complex natural language responses' do
      it 'handles response with context about child' do
        result = described_class.parse("She's been feeling that way most days lately")
        expect(result[:value]).to eq(2) # "most days" -> 2
      end

      it 'handles negative responses with elaboration' do
        result = described_class.parse("No, we haven't noticed that at all")
        expect(result[:value]).to eq(0)
      end
    end
  end

  describe '.validate' do
    it 'returns valid for acceptable response text' do
      result = described_class.validate('Several days')
      expect(result[:valid]).to be true
      expect(result[:errors]).to be_empty
    end

    it 'returns invalid for empty response' do
      result = described_class.validate('')
      expect(result[:valid]).to be false
      expect(result[:errors]).to include('Response text is required')
    end

    it 'returns invalid for response over 500 characters' do
      long_text = 'a' * 501
      result = described_class.validate(long_text)
      expect(result[:valid]).to be false
      expect(result[:errors]).to include('Response text must be 500 characters or less')
    end

    it 'returns valid for 500 character response' do
      text = 'a' * 500
      result = described_class.validate(text)
      expect(result[:valid]).to be true
    end
  end
end
