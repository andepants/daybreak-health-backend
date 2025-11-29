# frozen_string_literal: true

FactoryBot.define do
  factory :insurance do
    association :onboarding_session
    payer_name { 'Blue Cross Blue Shield' }
    subscriber_name { 'John Doe' }
    member_id { 'MEM123456789' }
    policy_number { 'ABC123456789' }
    group_number { 'GRP001' }
    card_image_front { 'base64_encoded_front_image_data' }
    card_image_back { 'base64_encoded_back_image_data' }
    verification_status { :pending }
    verification_result { {} }
  end
end
