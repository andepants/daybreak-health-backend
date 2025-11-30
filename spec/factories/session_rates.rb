# frozen_string_literal: true

FactoryBot.define do
  factory :session_rate do
    service_type { 'individual_therapy' }
    base_rate { 150.00 }
    effective_date { Date.current }
    end_date { nil }
    metadata { { source: 'test_factory' } }

    trait :intake do
      service_type { 'intake' }
      base_rate { 175.00 }
    end

    trait :family_therapy do
      service_type { 'family_therapy' }
      base_rate { 200.00 }
    end

    trait :onsite_care do
      service_type { 'onsite_care' }
      base_rate { 175.00 }
    end

    trait :expired do
      effective_date { 1.year.ago }
      end_date { 1.month.ago }
    end

    trait :future do
      effective_date { 1.month.from_now }
      end_date { 1.year.from_now }
    end
  end
end
