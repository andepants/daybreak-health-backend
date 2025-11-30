# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Assessments::QuestionSets do
  describe '.phq_a_questions' do
    context 'for children aged 5-12' do
      it 'returns simplified PHQ-A questions' do
        questions = described_class.phq_a_questions(age: 10)
        expect(questions).to eq(Assessments::QuestionSets::PHQ_A_SIMPLIFIED)
        expect(questions.length).to eq(9)
      end

      it 'uses simplified language' do
        questions = described_class.phq_a_questions(age: 8)
        expect(questions.first[:text]).to include('not wanted to do things')
      end
    end

    context 'for children aged 13-18' do
      it 'returns standard PHQ-A questions' do
        questions = described_class.phq_a_questions(age: 14)
        expect(questions).to eq(Assessments::QuestionSets::PHQ_A_STANDARD)
        expect(questions.length).to eq(9)
      end

      it 'uses standard clinical language' do
        questions = described_class.phq_a_questions(age: 16)
        expect(questions.first[:text]).to include('little interest or pleasure')
      end
    end

    it 'includes all required question metadata' do
      questions = described_class.phq_a_questions(age: 14)
      questions.each do |question|
        expect(question).to have_key(:id)
        expect(question).to have_key(:item)
        expect(question).to have_key(:domain)
        expect(question).to have_key(:text)
      end
    end
  end

  describe '.gad_7_questions' do
    context 'for children aged 5-12' do
      it 'returns simplified GAD-7 questions' do
        questions = described_class.gad_7_questions(age: 10)
        expect(questions).to eq(Assessments::QuestionSets::GAD_7_SIMPLIFIED)
        expect(questions.length).to eq(7)
      end
    end

    context 'for children aged 13-18' do
      it 'returns standard GAD-7 questions' do
        questions = described_class.gad_7_questions(age: 15)
        expect(questions).to eq(Assessments::QuestionSets::GAD_7_STANDARD)
        expect(questions.length).to eq(7)
      end
    end
  end

  describe '.all_questions' do
    it 'returns both PHQ-A and GAD-7 questions' do
      all = described_class.all_questions(age: 14)
      expect(all).to have_key(:phq_a)
      expect(all).to have_key(:gad_7)
      expect(all[:phq_a].length).to eq(9)
      expect(all[:gad_7].length).to eq(7)
    end
  end

  describe '.find_question' do
    it 'finds PHQ-A question by ID' do
      question = described_class.find_question(question_id: 'phq_a_1', age: 14)
      expect(question).to be_present
      expect(question[:item]).to eq(1)
      expect(question[:domain]).to eq('anhedonia')
    end

    it 'finds GAD-7 question by ID' do
      question = described_class.find_question(question_id: 'gad_7_3', age: 14)
      expect(question).to be_present
      expect(question[:item]).to eq(3)
      expect(question[:domain]).to eq('excessive_worry')
    end

    it 'returns nil for invalid question ID' do
      question = described_class.find_question(question_id: 'invalid', age: 14)
      expect(question).to be_nil
    end
  end

  describe '.next_question' do
    it 'returns next PHQ-A question' do
      next_q = described_class.next_question(current_question_id: 'phq_a_1', age: 14)
      expect(next_q[:id]).to eq('phq_a_2')
    end

    it 'transitions from PHQ-A to GAD-7' do
      next_q = described_class.next_question(current_question_id: 'phq_a_9', age: 14)
      expect(next_q[:id]).to eq('gad_7_1')
    end

    it 'returns nil after last GAD-7 question' do
      next_q = described_class.next_question(current_question_id: 'gad_7_7', age: 14)
      expect(next_q).to be_nil
    end

    it 'returns first question for invalid current question' do
      next_q = described_class.next_question(current_question_id: 'invalid', age: 14)
      expect(next_q[:id]).to eq('phq_a_1')
    end
  end

  describe '.question_by_item' do
    it 'finds PHQ-A question by item number' do
      question = described_class.question_by_item(instrument: 'phq_a', item: 5, age: 14)
      expect(question[:id]).to eq('phq_a_5')
      expect(question[:domain]).to eq('appetite')
    end

    it 'finds GAD-7 question by item number' do
      question = described_class.question_by_item(instrument: 'gad_7', item: 2, age: 14)
      expect(question[:id]).to eq('gad_7_2')
      expect(question[:domain]).to eq('worry_control')
    end
  end

  describe '.valid_question_id?' do
    it 'returns true for valid PHQ-A question' do
      expect(described_class.valid_question_id?(question_id: 'phq_a_5', age: 14)).to be true
    end

    it 'returns true for valid GAD-7 question' do
      expect(described_class.valid_question_id?(question_id: 'gad_7_7', age: 14)).to be true
    end

    it 'returns false for invalid question' do
      expect(described_class.valid_question_id?(question_id: 'phq_a_10', age: 14)).to be false
    end
  end

  describe '.total_questions' do
    it 'returns 16' do
      expect(described_class.total_questions).to eq(16)
    end
  end

  describe '.likert_options_text' do
    it 'returns natural language Likert options' do
      text = described_class.likert_options_text
      expect(text).to include('not at all')
      expect(text).to include('several days')
      expect(text).to include('more than half')
      expect(text).to include('nearly every day')
    end
  end

  describe '.phq_a_severity' do
    it 'returns minimal for score 0-4' do
      expect(described_class.phq_a_severity(4)[:level]).to eq(:minimal)
    end

    it 'returns mild for score 5-9' do
      expect(described_class.phq_a_severity(7)[:level]).to eq(:mild)
    end

    it 'returns moderate for score 10-14' do
      expect(described_class.phq_a_severity(12)[:level]).to eq(:moderate)
    end

    it 'returns moderately_severe for score 15-19' do
      expect(described_class.phq_a_severity(17)[:level]).to eq(:moderately_severe)
    end

    it 'returns severe for score 20-27' do
      expect(described_class.phq_a_severity(25)[:level]).to eq(:severe)
    end
  end

  describe '.gad_7_severity' do
    it 'returns minimal for score 0-4' do
      expect(described_class.gad_7_severity(3)[:level]).to eq(:minimal)
    end

    it 'returns mild for score 5-9' do
      expect(described_class.gad_7_severity(8)[:level]).to eq(:mild)
    end

    it 'returns moderate for score 10-14' do
      expect(described_class.gad_7_severity(11)[:level]).to eq(:moderate)
    end

    it 'returns severe for score 15-21' do
      expect(described_class.gad_7_severity(18)[:level]).to eq(:severe)
    end
  end
end
