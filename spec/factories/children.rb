# frozen_string_literal: true

FactoryBot.define do
  factory :child do
    association :onboarding_session
    first_name { 'Jane' }
    last_name { 'Doe' }
    date_of_birth { '2010-05-15' }
    gender { 'female' }
    school_name { 'Elementary School' }
    grade { '5th' }
  end
end
