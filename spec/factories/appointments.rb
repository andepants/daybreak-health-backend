# frozen_string_literal: true

FactoryBot.define do
  factory :appointment do
    association :therapist
    association :onboarding_session, status: :assessment_complete

    scheduled_at { 2.days.from_now.change(hour: 10, min: 0) }
    duration_minutes { 50 }
    status { :scheduled }
    location_type { 'virtual' }
    virtual_link { 'https://meet.daybreakhealth.com/session-123' }

    trait :confirmed do
      status { :confirmed }
      confirmed_at { 1.day.ago }
    end

    trait :cancelled do
      status { :cancelled }
      cancelled_at { 1.hour.ago }
      cancellation_reason { 'Parent requested cancellation' }
    end

    trait :completed do
      status { :completed }
      scheduled_at { 2.days.ago.change(hour: 10, min: 0) }
    end

    trait :no_show do
      status { :no_show }
      scheduled_at { 2.days.ago.change(hour: 10, min: 0) }
    end

    trait :upcoming do
      scheduled_at { 1.week.from_now.change(hour: 14, min: 0) }
    end

    trait :past do
      scheduled_at { 1.week.ago.change(hour: 14, min: 0) }
    end

    trait :today do
      scheduled_at { Time.current.change(hour: 15, min: 0) }
    end
  end
end
