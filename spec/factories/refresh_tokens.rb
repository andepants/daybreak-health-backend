# frozen_string_literal: true

FactoryBot.define do
  factory :refresh_token do
    association :onboarding_session
    device_fingerprint { Digest::SHA256.hexdigest("test-device-#{SecureRandom.hex(4)}") }
    ip_address { "192.168.1.#{rand(1..255)}" }
    user_agent { "Mozilla/5.0 (Test Browser #{SecureRandom.hex(2)})" }
    expires_at { 7.days.from_now }
    revoked_at { nil }

    # Set token via virtual attribute (will be hashed automatically)
    transient do
      plaintext_token { SecureRandom.urlsafe_base64(64) }
    end

    # Set the token after building (for both build and create)
    after(:build) do |refresh_token, evaluator|
      refresh_token.token = evaluator.plaintext_token
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :revoked do
      revoked_at { 1.hour.ago }
    end

    trait :valid do
      expires_at { 7.days.from_now }
      revoked_at { nil }
    end
  end
end
