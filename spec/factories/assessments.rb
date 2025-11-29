# frozen_string_literal: true

FactoryBot.define do
  factory :assessment do
    association :onboarding_session
    responses { { question1: 'answer1', question2: 'answer2' } }
    risk_flags { [] }
    summary { 'Assessment summary' }
    consent_given { false }
    score { 75 }
  end
end
