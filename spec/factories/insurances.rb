# frozen_string_literal: true

FactoryBot.define do
  factory :insurance do
    association :onboarding_session
    payer_name { "Blue Cross Blue Shield" }
    subscriber_name { "John Doe" }
    member_id { "MEM123456789" }
    policy_number { "ABC123456789" }
    group_number { "GRP001" }
    verification_status { :pending }
    verification_result { {} }

    # Trait for insurance with attached images
    trait :with_card_images do
      after(:create) do |insurance|
        insurance.card_image_front.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/test_image.jpg")),
          filename: "front.jpg",
          content_type: "image/jpeg"
        )
        insurance.card_image_back.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/test_image.jpg")),
          filename: "back.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    # Trait for front image only
    trait :with_front_image do
      after(:create) do |insurance|
        insurance.card_image_front.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/test_image.jpg")),
          filename: "front.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    # Trait for self-pay (no insurance)
    trait :self_pay do
      payer_name { nil }
      subscriber_name { nil }
      member_id { nil }
      policy_number { nil }
      group_number { nil }
      verification_status { :self_pay }
    end

    # Trait for verified insurance
    trait :verified do
      verification_status { :verified }
      verification_result do
        {
          eligible: true,
          copay: 25,
          deductible: 500,
          verified_at: Time.current.iso8601
        }
      end
    end

    # Trait for failed verification
    trait :failed do
      verification_status { :failed }
      verification_result do
        {
          eligible: false,
          reason: "Member not found",
          verified_at: Time.current.iso8601
        }
      end
    end

    # Trait for OCR complete (Story 4.2)
    trait :ocr_complete do
      verification_status { :ocr_complete }
      verification_result do
        {
          "ocr_extracted" => {
            "member_id" => "MEM123456789",
            "group_number" => "GRP001",
            "payer_name" => "Blue Cross Blue Shield",
            "subscriber_name" => "John Doe"
          },
          "ocr_confidence" => {
            "member_id" => 95.5,
            "group_number" => 92.3,
            "payer_name" => 88.7,
            "subscriber_name" => 91.2
          },
          "ocr_low_confidence_fields" => [],
          "ocr_completed_at" => Time.current.iso8601
        }
      end
    end

    # Trait for OCR needs review (low confidence)
    trait :ocr_needs_review do
      verification_status { :ocr_needs_review }
      verification_result do
        {
          "ocr_extracted" => {
            "member_id" => "MEM123456789",
            "group_number" => "GRP001",
            "payer_name" => "Blue Cross",
            "subscriber_name" => "John D"
          },
          "ocr_confidence" => {
            "member_id" => 92.0,
            "group_number" => 75.5,
            "payer_name" => 70.2,
            "subscriber_name" => 65.0
          },
          "ocr_low_confidence_fields" => ["group_number", "payer_name", "subscriber_name"],
          "ocr_completed_at" => Time.current.iso8601
        }
      end
    end

    # Trait for OCR failed
    trait :ocr_failed do
      verification_status { :failed }
      verification_result do
        {
          "error" => {
            "code" => "TIMEOUT",
            "message" => "OCR processing timed out",
            "occurred_at" => Time.current.iso8601
          }
        }
      end
    end
  end
end
