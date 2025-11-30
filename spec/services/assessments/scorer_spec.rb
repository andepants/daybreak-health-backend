# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Assessments::Scorer do
  let(:session) { create(:onboarding_session) }

  describe '#calculate_phq_a' do
    it 'returns nil for empty responses' do
      assessment = create(:assessment, onboarding_session: session, responses: '{"phq_a": [], "gad_7": []}')
      scorer = described_class.new(assessment)
      expect(scorer.calculate_phq_a).to be_nil
    end

    it 'calculates total PHQ-A score' do
      responses = {
        phq_a: [
          { item: 1, value: 2 },
          { item: 2, value: 3 },
          { item: 3, value: 1 }
        ],
        gad_7: [],
        scores: { phq_a_total: 6 }
      }
      assessment = create(:assessment, onboarding_session: session, responses: responses.to_json)
      scorer = described_class.new(assessment)
      result = scorer.calculate_phq_a

      expect(result[:total]).to eq(6)
      expect(result[:max]).to eq(27)
      expect(result[:complete]).to be false
      expect(result[:item_count]).to eq(3)
    end

    it 'determines severity level' do
      responses = {
        phq_a: (1..9).map { |i| { item: i, value: 2 } }, # Total = 18
        gad_7: [],
        scores: { phq_a_total: 18 }
      }
      assessment = create(:assessment, onboarding_session: session, responses: responses.to_json)
      scorer = described_class.new(assessment)
      result = scorer.calculate_phq_a

      expect(result[:severity][:level]).to eq(:moderately_severe)
      expect(result[:complete]).to be true
    end
  end

  describe '#calculate_gad_7' do
    it 'returns nil for empty responses' do
      assessment = create(:assessment, onboarding_session: session, responses: '{"phq_a": [], "gad_7": []}')
      scorer = described_class.new(assessment)
      expect(scorer.calculate_gad_7).to be_nil
    end

    it 'calculates total GAD-7 score' do
      responses = {
        phq_a: [],
        gad_7: [
          { item: 1, value: 1 },
          { item: 2, value: 2 },
          { item: 3, value: 3 }
        ],
        scores: { gad_7_total: 6 }
      }
      assessment = create(:assessment, onboarding_session: session, responses: responses.to_json)
      scorer = described_class.new(assessment)
      result = scorer.calculate_gad_7

      expect(result[:total]).to eq(6)
      expect(result[:max]).to eq(21)
      expect(result[:complete]).to be false
    end

    it 'determines severity level' do
      responses = {
        phq_a: [],
        gad_7: (1..7).map { |i| { item: i, value: 2 } }, # Total = 14
        scores: { gad_7_total: 14 }
      }
      assessment = create(:assessment, onboarding_session: session, responses: responses.to_json)
      scorer = described_class.new(assessment)
      result = scorer.calculate_gad_7

      expect(result[:severity][:level]).to eq(:moderate)
      expect(result[:complete]).to be true
    end
  end

  describe '#calculate_combined' do
    it 'returns normalized score out of 100' do
      responses = {
        phq_a: (1..9).map { |i| { item: i, value: 1 } }, # Total = 9
        gad_7: (1..7).map { |i| { item: i, value: 1 } }, # Total = 7
        scores: { phq_a_total: 9, gad_7_total: 7 }
      }
      assessment = create(:assessment, onboarding_session: session, responses: responses.to_json)
      scorer = described_class.new(assessment)
      result = scorer.calculate_combined

      expect(result[:raw_total]).to eq(16)
      # 16/48 = 33.33%
      expect(result[:normalized_score]).to eq(33)
    end

    it 'determines overall severity from highest component' do
      responses = {
        phq_a: (1..9).map { |i| { item: i, value: 3 } }, # Severe = 27
        gad_7: (1..7).map { |i| { item: i, value: 0 } }, # Minimal = 0
        scores: { phq_a_total: 27, gad_7_total: 0 }
      }
      assessment = create(:assessment, onboarding_session: session, responses: responses.to_json)
      scorer = described_class.new(assessment)
      result = scorer.calculate_combined

      expect(result[:overall_severity]).to eq(:severe)
    end
  end

  describe '#detect_risk_indicators' do
    it 'detects suicidal ideation from PHQ-A item 9' do
      responses = {
        phq_a: [{ item: 9, value: 2 }], # Moderate frequency
        gad_7: [],
        scores: {}
      }
      assessment = create(:assessment, onboarding_session: session, responses: responses.to_json)
      scorer = described_class.new(assessment)
      indicators = scorer.detect_risk_indicators

      expect(indicators.length).to eq(1)
      expect(indicators.first[:type]).to eq(:suicidal_ideation)
      expect(indicators.first[:severity]).to eq(:moderate)
      expect(indicators.first[:requires_immediate_attention]).to be true
    end

    it 'does not flag suicidal ideation with value 0' do
      responses = {
        phq_a: [{ item: 9, value: 0 }],
        gad_7: [],
        scores: {}
      }
      assessment = create(:assessment, onboarding_session: session, responses: responses.to_json)
      scorer = described_class.new(assessment)
      indicators = scorer.detect_risk_indicators

      expect(indicators).to be_empty
    end

    it 'detects severe depression' do
      responses = {
        phq_a: (1..9).map { |i| { item: i, value: 3 } }, # Total = 27 (severe)
        gad_7: [],
        scores: {}
      }
      assessment = create(:assessment, onboarding_session: session, responses: responses.to_json)
      scorer = described_class.new(assessment)
      indicators = scorer.detect_risk_indicators

      severe_depression = indicators.find { |i| i[:type] == :severe_depression }
      expect(severe_depression).to be_present
      expect(severe_depression[:requires_clinical_review]).to be true
    end

    it 'detects severe anxiety' do
      responses = {
        phq_a: [],
        gad_7: (1..7).map { |i| { item: i, value: 3 } }, # Total = 21 (severe)
        scores: {}
      }
      assessment = create(:assessment, onboarding_session: session, responses: responses.to_json)
      scorer = described_class.new(assessment)
      indicators = scorer.detect_risk_indicators

      severe_anxiety = indicators.find { |i| i[:type] == :severe_anxiety }
      expect(severe_anxiety).to be_present
      expect(severe_anxiety[:requires_clinical_review]).to be true
    end
  end

  describe '#update_risk_flags' do
    it 'updates assessment risk_flags array' do
      responses = {
        phq_a: [{ item: 9, value: 2 }],
        gad_7: [],
        scores: {}
      }
      assessment = create(:assessment, onboarding_session: session, responses: responses.to_json)
      scorer = described_class.new(assessment)
      flags = scorer.update_risk_flags

      expect(flags).to include('suicidal_ideation')
      expect(assessment.risk_flags).to include('suicidal_ideation')
    end
  end

  describe '#generate_summary' do
    it 'generates clinical summary text' do
      responses = {
        phq_a: (1..9).map { |i| { item: i, value: 1 } },
        gad_7: (1..7).map { |i| { item: i, value: 1 } },
        scores: { phq_a_total: 9, gad_7_total: 7 }
      }
      assessment = create(:assessment, onboarding_session: session, responses: responses.to_json)
      scorer = described_class.new(assessment)
      summary = scorer.generate_summary

      expect(summary).to include('PHQ-A: 9/27')
      expect(summary).to include('GAD-7: 7/21')
      expect(summary).to include('Mild')
    end
  end
end
