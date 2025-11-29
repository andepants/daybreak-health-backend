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
end
