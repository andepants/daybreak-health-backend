# frozen_string_literal: true

FactoryBot.define do
  factory :assessment do
    association :onboarding_session
    responses { { phq_a: [], gad_7: [], progress: {}, scores: {} }.to_json }
    risk_flags { [] }
    summary { nil }
    consent_given { true }
    score { nil }
    status { :not_started }

    trait :in_progress do
      status { :in_progress }
    end

    trait :complete do
      status { :complete }
      responses do
        {
          phq_a: (1..9).map { |i| { item: i, value: 1, raw_text: 'several days' } },
          gad_7: (1..7).map { |i| { item: i, value: 1, raw_text: 'several days' } },
          scores: { phq_a_total: 9, gad_7_total: 7 },
          progress: { phq_a_complete: true, gad_7_complete: true }
        }.to_json
      end
      score { 33 }
    end

    trait :with_phq_a_responses do
      responses do
        {
          phq_a: (1..9).map { |i| { item: i, value: 1, raw_text: 'several days' } },
          gad_7: [],
          scores: { phq_a_total: 9 },
          progress: { phq_a_complete: true, current_instrument: 'gad_7', next_question_id: 'gad_7_1' }
        }.to_json
      end
    end

    trait :with_risk_indicators do
      responses do
        {
          phq_a: [{ item: 9, value: 2, raw_text: 'more than half the days' }],
          gad_7: [],
          scores: { phq_a_total: 2 },
          progress: {}
        }.to_json
      end
      risk_flags { ['suicidal_ideation'] }
    end
  end
end
