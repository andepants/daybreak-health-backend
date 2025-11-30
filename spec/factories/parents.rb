# frozen_string_literal: true

FactoryBot.define do
  factory :parent do
    association :onboarding_session
    email { 'parent@example.com' }
    phone { '+12025551234' }
    first_name { 'John' }
    last_name { 'Doe' }
    relationship { :parent }
    is_guardian { true }
  end
end
