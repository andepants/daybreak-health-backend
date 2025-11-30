# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Assessment, type: :model do
  describe 'associations' do
    it { should belong_to(:onboarding_session) }
  end

  describe 'validations' do
    it { should validate_presence_of(:responses) }
    it { should validate_presence_of(:onboarding_session) }

    it 'validates consent_given is boolean' do
      assessment = build(:assessment, consent_given: nil)
      expect(assessment).not_to be_valid
      expect(assessment.errors[:consent_given]).to be_present
    end

    describe 'score validation' do
      it 'allows score between 0 and 100' do
        assessment = build(:assessment, score: 50)
        expect(assessment).to be_valid
      end

      it 'allows score of 0' do
        assessment = build(:assessment, score: 0)
        expect(assessment).to be_valid
      end

      it 'allows score of 100' do
        assessment = build(:assessment, score: 100)
        expect(assessment).to be_valid
      end

      it 'rejects score less than 0' do
        assessment = build(:assessment, score: -1)
        expect(assessment).not_to be_valid
        expect(assessment.errors[:score]).to be_present
      end

      it 'rejects score greater than 100' do
        assessment = build(:assessment, score: 101)
        expect(assessment).not_to be_valid
        expect(assessment.errors[:score]).to be_present
      end

      it 'allows nil score' do
        assessment = build(:assessment, score: nil)
        expect(assessment).to be_valid
      end

      it 'rejects non-integer score' do
        assessment = build(:assessment, score: 75.5)
        expect(assessment).not_to be_valid
        expect(assessment.errors[:score]).to be_present
      end
    end
  end

  describe 'UUID primary key' do
    it 'generates UUID for id' do
      assessment = create(:assessment)
      expect(assessment.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end

  describe 'timestamps' do
    it 'sets created_at and updated_at' do
      assessment = create(:assessment)
      expect(assessment.created_at).to be_present
      expect(assessment.updated_at).to be_present
    end
  end

  # Story 5.1: Conversational Screening Questions
  describe 'status enum' do
    it 'defines status values' do
      expect(Assessment.statuses).to eq({
        'not_started' => 0,
        'in_progress' => 1,
        'complete' => 2
      })
    end

    it 'defaults to not_started' do
      assessment = build(:assessment)
      expect(assessment.not_started?).to be true
    end
  end

  describe 'status transitions' do
    let(:assessment) { create(:assessment, status: :not_started) }

    it 'allows transition from not_started to in_progress' do
      assessment.status = :in_progress
      expect(assessment).to be_valid
    end

    it 'allows transition from in_progress to complete' do
      assessment.update!(status: :in_progress)
      assessment.status = :complete
      expect(assessment).to be_valid
    end

    it 'prevents transition from complete to in_progress' do
      assessment.update!(status: :in_progress)
      assessment.update!(status: :complete)
      assessment.status = :in_progress
      expect(assessment).not_to be_valid
      expect(assessment.errors[:status]).to include('cannot transition from complete to in_progress')
    end
  end

  describe '#parsed_responses' do
    it 'returns empty hash for blank responses' do
      assessment = build(:assessment, responses: '')
      expect(assessment.parsed_responses).to eq({})
    end

    it 'parses JSON string responses' do
      assessment = build(:assessment, responses: '{"phq_a": [], "gad_7": []}')
      expect(assessment.parsed_responses).to eq({ phq_a: [], gad_7: [] })
    end

    it 'returns hash responses as-is' do
      assessment = build(:assessment, responses: { phq_a: [], gad_7: [] })
      expect(assessment.parsed_responses).to eq({ phq_a: [], gad_7: [] })
    end
  end

  describe '#phq_a_responses' do
    it 'returns PHQ-A responses array' do
      responses = { phq_a: [{ item: 1, value: 2 }], gad_7: [] }
      assessment = build(:assessment, responses: responses.to_json)
      expect(assessment.phq_a_responses).to eq([{ item: 1, value: 2 }])
    end

    it 'returns empty array when no PHQ-A responses' do
      assessment = build(:assessment, responses: '{}')
      expect(assessment.phq_a_responses).to eq([])
    end
  end

  describe '#gad_7_responses' do
    it 'returns GAD-7 responses array' do
      responses = { phq_a: [], gad_7: [{ item: 1, value: 1 }] }
      assessment = build(:assessment, responses: responses.to_json)
      expect(assessment.gad_7_responses).to eq([{ item: 1, value: 1 }])
    end
  end

  describe '#phq_a_complete?' do
    it 'returns true when 9 PHQ-A responses' do
      responses = { phq_a: (1..9).map { |i| { item: i, value: 1 } }, gad_7: [] }
      assessment = build(:assessment, responses: responses.to_json)
      expect(assessment.phq_a_complete?).to be true
    end

    it 'returns false when less than 9 PHQ-A responses' do
      responses = { phq_a: [{ item: 1, value: 1 }], gad_7: [] }
      assessment = build(:assessment, responses: responses.to_json)
      expect(assessment.phq_a_complete?).to be false
    end
  end

  describe '#gad_7_complete?' do
    it 'returns true when 7 GAD-7 responses' do
      responses = { phq_a: [], gad_7: (1..7).map { |i| { item: i, value: 1 } } }
      assessment = build(:assessment, responses: responses.to_json)
      expect(assessment.gad_7_complete?).to be true
    end

    it 'returns false when less than 7 GAD-7 responses' do
      responses = { phq_a: [], gad_7: [{ item: 1, value: 1 }] }
      assessment = build(:assessment, responses: responses.to_json)
      expect(assessment.gad_7_complete?).to be false
    end
  end

  describe '#assessment_complete?' do
    it 'returns true when both instruments complete' do
      responses = {
        phq_a: (1..9).map { |i| { item: i, value: 1 } },
        gad_7: (1..7).map { |i| { item: i, value: 1 } }
      }
      assessment = build(:assessment, responses: responses.to_json)
      expect(assessment.assessment_complete?).to be true
    end

    it 'returns false when PHQ-A incomplete' do
      responses = {
        phq_a: [{ item: 1, value: 1 }],
        gad_7: (1..7).map { |i| { item: i, value: 1 } }
      }
      assessment = build(:assessment, responses: responses.to_json)
      expect(assessment.assessment_complete?).to be false
    end
  end

  describe '#completed_questions_count' do
    it 'returns total completed questions' do
      responses = {
        phq_a: [{ item: 1, value: 1 }, { item: 2, value: 2 }],
        gad_7: [{ item: 1, value: 0 }]
      }
      assessment = build(:assessment, responses: responses.to_json)
      expect(assessment.completed_questions_count).to eq(3)
    end
  end

  describe '#progress_percentage' do
    it 'returns 0 for no responses' do
      assessment = build(:assessment, responses: '{"phq_a": [], "gad_7": []}')
      expect(assessment.progress_percentage).to eq(0)
    end

    it 'returns 100 for complete assessment' do
      responses = {
        phq_a: (1..9).map { |i| { item: i, value: 1 } },
        gad_7: (1..7).map { |i| { item: i, value: 1 } }
      }
      assessment = build(:assessment, responses: responses.to_json)
      expect(assessment.progress_percentage).to eq(100)
    end

    it 'returns correct percentage for partial completion' do
      responses = {
        phq_a: (1..4).map { |i| { item: i, value: 1 } }, # 4 of 16 = 25%
        gad_7: []
      }
      assessment = build(:assessment, responses: responses.to_json)
      expect(assessment.progress_percentage).to eq(25)
    end
  end

  describe '#add_response' do
    let(:assessment) { create(:assessment, responses: '{"phq_a": [], "gad_7": []}') }

    it 'adds valid response to PHQ-A' do
      result = assessment.add_response(
        instrument: 'phq_a',
        item: 1,
        value: 2,
        raw_text: 'more than half the days',
        question_text: 'Question 1'
      )

      expect(result).to be true
      expect(assessment.phq_a_responses.length).to eq(1)
      expect(assessment.phq_a_responses.first[:value]).to eq(2)
    end

    it 'rejects value out of range (> 3)' do
      result = assessment.add_response(
        instrument: 'phq_a',
        item: 1,
        value: 4,
        raw_text: 'always',
        question_text: 'Question 1'
      )

      expect(result).to be false
      expect(assessment.errors[:base]).to include('Response value must be between 0 and 3')
    end

    it 'rejects value out of range (< 0)' do
      result = assessment.add_response(
        instrument: 'phq_a',
        item: 1,
        value: -1,
        raw_text: 'never',
        question_text: 'Question 1'
      )

      expect(result).to be false
    end

    it 'rejects empty raw_text' do
      result = assessment.add_response(
        instrument: 'phq_a',
        item: 1,
        value: 1,
        raw_text: '',
        question_text: 'Question 1'
      )

      expect(result).to be false
      expect(assessment.errors[:base]).to include('Response text must be 1-500 characters')
    end

    it 'rejects raw_text over 500 characters' do
      result = assessment.add_response(
        instrument: 'phq_a',
        item: 1,
        value: 1,
        raw_text: 'a' * 501,
        question_text: 'Question 1'
      )

      expect(result).to be false
    end

    it 'rejects duplicate responses' do
      assessment.add_response(
        instrument: 'phq_a',
        item: 1,
        value: 1,
        raw_text: 'several days',
        question_text: 'Question 1'
      )
      assessment.save!

      result = assessment.add_response(
        instrument: 'phq_a',
        item: 1,
        value: 2,
        raw_text: 'more than half',
        question_text: 'Question 1'
      )

      expect(result).to be false
      expect(assessment.errors[:base]).to include('Question already answered')
    end

    it 'updates scores after adding response' do
      assessment.add_response(
        instrument: 'phq_a',
        item: 1,
        value: 2,
        raw_text: 'more than half',
        question_text: 'Question 1'
      )
      assessment.save!

      expect(assessment.phq_a_score).to eq(2)
    end
  end

  describe '#phq_a_score' do
    it 'returns total PHQ-A score' do
      responses = {
        phq_a: [
          { item: 1, value: 2 },
          { item: 2, value: 3 }
        ],
        gad_7: [],
        scores: { phq_a_total: 5 }
      }
      assessment = build(:assessment, responses: responses.to_json)
      expect(assessment.phq_a_score).to eq(5)
    end
  end

  describe '#gad_7_score' do
    it 'returns total GAD-7 score' do
      responses = {
        phq_a: [],
        gad_7: [
          { item: 1, value: 1 },
          { item: 2, value: 2 }
        ],
        scores: { gad_7_total: 3 }
      }
      assessment = build(:assessment, responses: responses.to_json)
      expect(assessment.gad_7_score).to eq(3)
    end
  end
end
