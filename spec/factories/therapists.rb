# frozen_string_literal: true

FactoryBot.define do
  factory :therapist do
    sequence(:first_name) { |n| "Therapist#{n}" }
    sequence(:last_name) { |n| "Last#{n}" }
    sequence(:email) { |n| "therapist#{n}@example.com" }
    phone { '+15551234567' }
    license_type { %w[LCSW LMFT LPCC LMHC LPC].sample }
    sequence(:license_number) { |n| "#{license_type}#{100000 + n}" }
    license_state { %w[CA TX NY FL].sample }
    license_expiration { 2.years.from_now.to_date }
    sequence(:npi_number) { |n| (1234567890 + n).to_s }
    bio { 'I am passionate about helping children and adolescents navigate mental health challenges.' }
    photo_url { nil }
    active { true }
    languages { ['en'] }
    age_ranges { ['5-12', '13-17'] }
    treatment_modalities { %w[cbt dbt] }
    external_id { SecureRandom.uuid }

    trait :inactive do
      active { false }
    end

    trait :with_specializations do
      after(:create) do |therapist|
        create_list(:therapist_specialization, 2, therapist: therapist)
      end
    end

    trait :with_insurance_panels do
      after(:create) do |therapist|
        create_list(:therapist_insurance_panel, 2, therapist: therapist)
      end
    end

    trait :california do
      license_state { 'CA' }
    end

    trait :texas do
      license_state { 'TX' }
    end
  end

  factory :therapist_specialization do
    association :therapist
    specialization { %w[anxiety depression adhd trauma ptsd behavioral_issues].sample }
  end

  factory :therapist_insurance_panel do
    association :therapist
    insurance_name { %w[Aetna Cigna UnitedHealthcare BlueCross Molina].sample }
    insurance_state { %w[CA TX NY FL].sample }
    line_of_business { %w[Commercial Medicaid Medicare].sample }
    network_status { :in_network }
    external_insurance_id { SecureRandom.uuid }

    trait :out_of_network do
      network_status { :out_of_network }
    end
  end

  factory :therapist_availability do
    association :therapist
    day_of_week { (0..6).to_a.sample }
    start_time { Time.parse('09:00') }
    end_time { Time.parse('17:00') }
    timezone { 'America/Los_Angeles' }
    is_repeating { true }

    trait :monday do
      day_of_week { 1 }
    end

    trait :tuesday do
      day_of_week { 2 }
    end

    trait :wednesday do
      day_of_week { 3 }
    end

    trait :morning do
      start_time { Time.parse('09:00') }
      end_time { Time.parse('12:00') }
    end

    trait :afternoon do
      start_time { Time.parse('13:00') }
      end_time { Time.parse('17:00') }
    end

    trait :eastern_time do
      timezone { 'America/New_York' }
    end
  end

  factory :therapist_time_off do
    association :therapist
    start_date { 1.week.from_now.to_date }
    end_date { 2.weeks.from_now.to_date }
    reason { 'Vacation' }

    trait :one_day do
      start_date { 1.week.from_now.to_date }
      end_date { 1.week.from_now.to_date }
    end

    trait :conference do
      reason { 'Professional Conference' }
    end
  end

  factory :therapist_match do
    association :onboarding_session
    matched_therapists do
      [
        {
          therapist_id: SecureRandom.uuid,
          therapist_name: "Test Therapist",
          score: 85,
          reasoning: "Good match for your child's needs"
        }
      ]
    end
    criteria_used do
      {
        child_age: 10,
        concerns: ["anxiety"],
        insurance_payer: "Aetna"
      }
    end
    processing_time_ms { 1500 }
    selected_therapist_id { nil }

    trait :with_selection do
      selected_therapist_id { SecureRandom.uuid }
    end
  end
end
