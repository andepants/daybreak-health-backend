# frozen_string_literal: true

FactoryBot.define do
  factory :onboarding_session do
    status { :started }
    progress { {} }
    expires_at { 24.hours.from_now }
    referral_source { 'web' }

    trait :with_parent do
      after(:create) do |session|
        create(:parent, onboarding_session: session)
      end
    end

    trait :with_progress do
      progress do
        {
          currentStep: 'parent_info',
          completedSteps: ['welcome'],
          intake: {
            parentInfo: { status: 'complete' },
            childInfo: { status: 'pending' }
          }
        }
      end
    end

    trait :with_child do
      after(:create) do |session|
        create(:child, onboarding_session: session)
      end
    end

    trait :with_insurance do
      after(:create) do |session|
        create(:insurance, onboarding_session: session)
      end
    end

    trait :with_assessment do
      after(:create) do |session|
        create(:assessment, onboarding_session: session)
      end
    end
  end
end
