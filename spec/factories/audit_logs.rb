# frozen_string_literal: true

FactoryBot.define do
  factory :audit_log do
    association :onboarding_session
    user_id { SecureRandom.uuid }
    action { 'SESSION_CREATED' }
    resource { 'OnboardingSession' }
    resource_id { SecureRandom.uuid }
    details { {} }
    ip_address { '127.0.0.1' }
    user_agent { 'Mozilla/5.0' }
  end
end
