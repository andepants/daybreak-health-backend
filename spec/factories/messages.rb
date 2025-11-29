# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    association :onboarding_session
    role { :user }
    content { 'This is a test message' }
    metadata { {} }
  end
end
