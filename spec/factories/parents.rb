# frozen_string_literal: true

FactoryBot.define do
  factory :parent do
    association :onboarding_session
    email { 'parent@example.com' }
    phone { '+1 (555) 123-4567' }
    first_name { 'John' }
    last_name { 'Doe' }
    relationship { 'mother' }
    is_guardian { true }
  end
end
