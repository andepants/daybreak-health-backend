# frozen_string_literal: true

FactoryBot.define do
  factory :self_pay_rate do
    session_type { "individual_therapy" }
    base_rate { 75.00 }
    effective_date { Date.current }
    end_date { nil }
    sliding_scale_available { true }
    package_pricing_available { true }
    description { "Individual therapy session (50 minutes)" }
    metadata do
      {
        sliding_scale_tiers: [
          { income_range: "0-25000", discount_percent: 50 },
          { income_range: "25001-50000", discount_percent: 30 }
        ],
        package_options: [
          { sessions: 4, total_price: 280, savings: 20, description: "4-session bundle" },
          { sessions: 8, total_price: 560, savings: 40, description: "8-session bundle" }
        ]
      }
    end

    trait :family_therapy do
      session_type { "family_therapy" }
      base_rate { 100.00 }
      description { "Family therapy session (50 minutes)" }
      metadata do
        {
          sliding_scale_tiers: [
            { income_range: "0-25000", discount_percent: 50 }
          ],
          package_options: [
            { sessions: 4, total_price: 380, savings: 20, description: "4-session bundle" }
          ]
        }
      end
    end

    trait :intake do
      session_type { "intake" }
      base_rate { 150.00 }
      description { "Initial intake assessment (90 minutes)" }
      package_pricing_available { false }
      metadata do
        {
          sliding_scale_tiers: [
            { income_range: "0-25000", discount_percent: 50 }
          ]
        }
      end
    end

    trait :expired do
      effective_date { 1.year.ago }
      end_date { 1.day.ago }
    end

    trait :future do
      effective_date { 1.month.from_now }
    end

    trait :without_sliding_scale do
      sliding_scale_available { false }
      metadata { { package_options: [] } }
    end

    trait :without_packages do
      package_pricing_available { false }
      metadata { { sliding_scale_tiers: [] } }
    end
  end
end
