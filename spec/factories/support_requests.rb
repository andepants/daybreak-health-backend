# frozen_string_literal: true

FactoryBot.define do
  factory :support_request do
    association :onboarding_session
    intercom_conversation_id { "conv_#{SecureRandom.hex(8)}" }
    source { 'insurance-verification' }
    resolved { false }

    trait :resolved do
      resolved { true }
    end

    trait :from_welcome_screen do
      source { 'welcome-screen' }
    end

    trait :from_ai_intake do
      source { 'ai-intake' }
    end

    trait :from_assessment do
      source { 'assessment' }
    end

    trait :from_error_state do
      source { 'error-state' }
    end

    trait :without_conversation_id do
      intercom_conversation_id { nil }
    end
  end
end
