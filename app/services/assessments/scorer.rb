# frozen_string_literal: true

module Assessments
  # Scorer for mental health screening assessments
  # Story 5.1: Conversational Screening Questions
  #
  # Calculates instrument totals and severity levels for
  # PHQ-A (0-27) and GAD-7 (0-21) screening instruments.
  class Scorer
    attr_reader :assessment

    # Initialize scorer with an assessment
    #
    # @param assessment [Assessment] Assessment model instance
    def initialize(assessment)
      @assessment = assessment
    end

    # Calculate all scores
    #
    # @return [Hash] Scores including totals, severities, and clinical flags
    def calculate_all
      {
        phq_a: calculate_phq_a,
        gad_7: calculate_gad_7,
        combined: calculate_combined,
        risk_indicators: detect_risk_indicators
      }
    end

    # Calculate PHQ-A score
    #
    # @return [Hash] PHQ-A score with total and severity
    def calculate_phq_a
      responses = assessment.phq_a_responses
      return nil if responses.empty?

      total = responses.sum { |r| r[:value] || 0 }
      severity = QuestionSets.phq_a_severity(total)

      {
        total: total,
        max: 27,
        severity: severity,
        complete: responses.length == 9,
        item_count: responses.length
      }
    end

    # Calculate GAD-7 score
    #
    # @return [Hash] GAD-7 score with total and severity
    def calculate_gad_7
      responses = assessment.gad_7_responses
      return nil if responses.empty?

      total = responses.sum { |r| r[:value] || 0 }
      severity = QuestionSets.gad_7_severity(total)

      {
        total: total,
        max: 21,
        severity: severity,
        complete: responses.length == 7,
        item_count: responses.length
      }
    end

    # Calculate combined/overall score
    #
    # @return [Hash] Combined score normalized to 0-100
    def calculate_combined
      phq_a = calculate_phq_a
      gad_7 = calculate_gad_7

      return nil if phq_a.nil? && gad_7.nil?

      phq_total = phq_a&.dig(:total) || 0
      gad_total = gad_7&.dig(:total) || 0
      max_combined = 48 # 27 + 21

      raw_combined = phq_total + gad_total
      normalized = ((raw_combined.to_f / max_combined) * 100).round

      {
        raw_total: raw_combined,
        normalized_score: normalized,
        overall_severity: determine_overall_severity(phq_a, gad_7)
      }
    end

    # Detect risk indicators from responses
    # Story 5.3 preparation: Identifies self-harm and other risk flags
    #
    # @return [Array<Hash>] Risk indicators with type and severity
    def detect_risk_indicators
      indicators = []

      # Check PHQ-A item 9 (suicidal ideation)
      phq_a_responses = assessment.phq_a_responses
      item_9 = phq_a_responses.find { |r| r[:item] == 9 }

      if item_9 && item_9[:value].to_i > 0
        indicators << {
          type: :suicidal_ideation,
          severity: item_severity(item_9[:value]),
          item: 'phq_a_9',
          value: item_9[:value],
          requires_immediate_attention: item_9[:value].to_i >= 2
        }
      end

      # Check for severe depression (PHQ-A >= 20)
      phq_a_total = phq_a_responses.sum { |r| r[:value] || 0 }
      if phq_a_total >= 20
        indicators << {
          type: :severe_depression,
          severity: :high,
          score: phq_a_total,
          requires_clinical_review: true
        }
      end

      # Check for severe anxiety (GAD-7 >= 15)
      gad_7_responses = assessment.gad_7_responses
      gad_7_total = gad_7_responses.sum { |r| r[:value] || 0 }
      if gad_7_total >= 15
        indicators << {
          type: :severe_anxiety,
          severity: :high,
          score: gad_7_total,
          requires_clinical_review: true
        }
      end

      indicators
    end

    # Update assessment risk flags based on detected indicators
    #
    # @return [Array<String>] Updated risk flags
    def update_risk_flags
      indicators = detect_risk_indicators
      flags = indicators.map { |i| i[:type].to_s }

      assessment.risk_flags = flags.uniq
      flags
    end

    # Generate clinical summary
    # Story 5.4 preparation: Creates summary for clinician review
    #
    # @return [String] Clinical summary text
    def generate_summary
      scores = calculate_all

      summary_parts = []

      # PHQ-A summary
      if scores[:phq_a]
        phq = scores[:phq_a]
        summary_parts << "PHQ-A: #{phq[:total]}/27 (#{phq[:severity][:label]})"
      end

      # GAD-7 summary
      if scores[:gad_7]
        gad = scores[:gad_7]
        summary_parts << "GAD-7: #{gad[:total]}/21 (#{gad[:severity][:label]})"
      end

      # Risk indicators
      if scores[:risk_indicators].any?
        risk_text = scores[:risk_indicators].map do |r|
          "#{r[:type].to_s.humanize}: #{r[:severity]}"
        end.join(', ')
        summary_parts << "Risk Indicators: #{risk_text}"
      end

      # Overall
      if scores[:combined]
        summary_parts << "Overall Severity: #{scores[:combined][:overall_severity]}"
      end

      summary_parts.join("\n")
    end

    private

    # Determine overall severity from instrument scores
    def determine_overall_severity(phq_a, gad_7)
      severities = []
      severities << phq_a[:severity][:level] if phq_a
      severities << gad_7[:severity][:level] if gad_7

      return :unknown if severities.empty?

      # Return highest severity
      severity_order = [:minimal, :mild, :moderate, :moderately_severe, :severe]
      severities.max_by { |s| severity_order.index(s) || 0 }
    end

    # Map item value to severity level
    def item_severity(value)
      case value.to_i
      when 0 then :none
      when 1 then :mild
      when 2 then :moderate
      when 3 then :severe
      else :unknown
      end
    end
  end
end
