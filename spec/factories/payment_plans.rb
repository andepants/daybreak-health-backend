# frozen_string_literal: true

FactoryBot.define do
  factory :payment_plan do
    association :onboarding_session

    plan_duration_months { 6 }
    monthly_amount { 100.00 }
    total_amount { 600.00 }
    discount_applied { 0.00 }
    payment_method_preference { :card }
    status { :pending }

    trait :upfront do
      plan_duration_months { 0 }
      monthly_amount { 950.00 }
      total_amount { 950.00 }
      discount_applied { 50.00 }
    end

    trait :three_month do
      plan_duration_months { 3 }
      monthly_amount { 400.00 }
      total_amount { 1200.00 }
      discount_applied { 0.00 }
    end

    trait :six_month do
      plan_duration_months { 6 }
      monthly_amount { 200.00 }
      total_amount { 1200.00 }
      discount_applied { 0.00 }
    end

    trait :twelve_month do
      plan_duration_months { 12 }
      monthly_amount { 100.00 }
      total_amount { 1200.00 }
      discount_applied { 0.00 }
    end

    trait :hsa_fsa do
      payment_method_preference { :hsa_fsa }
    end

    trait :bank_transfer do
      payment_method_preference { :bank_transfer }
    end

    trait :active do
      status { :active }
    end

    trait :completed do
      status { :completed }
    end

    trait :cancelled do
      status { :cancelled }
    end
  end
end
