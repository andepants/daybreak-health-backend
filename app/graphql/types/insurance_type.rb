# frozen_string_literal: true

module Types
  # GraphQL type for Insurance model
  #
  # Represents the insurance information for an onboarding session.
  # PHI fields (subscriber_name, policy_number, etc.) are encrypted at rest.
  # Card images are stored in S3 with SSE-KMS encryption and accessed via presigned URLs.
  class InsuranceType < Types::BaseObject
    description "Insurance information"

    field :id, ID, null: false, description: "Unique identifier"
    field :payer_name, String, null: true, description: "Insurance payer/company name"
    field :subscriber_name, String, null: true, description: "Name on insurance policy (encrypted)"
    field :member_id, String, null: true, description: "Member ID (encrypted)"
    field :policy_number, String, null: true, description: "Policy number (encrypted)"
    field :group_number, String, null: true, description: "Group number (encrypted)"
    field :subscriber_dob, String, null: true, description: "Subscriber date of birth (encrypted)"
    field :verification_status, String, null: false, description: "Status of insurance verification"
    field :verification_result, GraphQL::Types::JSON, null: true, description: "Verification result details"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When record was created"
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When record was last updated"

    # Presigned URLs for card images (AC6)
    field :card_image_front_url, String, null: true, description: "Presigned URL for front card image (15-min expiry)"
    field :card_image_back_url, String, null: true, description: "Presigned URL for back card image (15-min expiry)"

    # OCR-related fields (Story 4.2)
    field :ocr_extracted, GraphQL::Types::JSON, null: true, description: "OCR-extracted field values"
    field :ocr_confidence, GraphQL::Types::JSON, null: true, description: "Confidence scores for extracted fields"
    field :ocr_low_confidence_fields, [String], null: true, description: "Fields with low confidence that need review"
    field :needs_review, Boolean, null: false, description: "Whether OCR extraction needs manual review"
    field :ocr_processed, Boolean, null: false, description: "Whether OCR processing has completed"
    field :ocr_error, GraphQL::Types::JSON, null: true, description: "OCR processing error if any"

    # Resolver for front image URL
    def card_image_front_url
      object.front_image_url(expires_in: 15.minutes)
    end

    # Resolver for back image URL
    def card_image_back_url
      object.back_image_url(expires_in: 15.minutes)
    end

    # OCR resolvers
    def ocr_extracted
      object.ocr_extracted
    end

    def ocr_confidence
      object.ocr_confidence
    end

    def ocr_low_confidence_fields
      object.ocr_low_confidence_fields
    end

    def needs_review
      object.needs_ocr_review?
    end

    def ocr_processed
      object.ocr_processed?
    end

    def ocr_error
      object.ocr_error
    end

    # Story 4.3: Manual entry helper
    field :ocr_data_available, Boolean, null: false, description: "Whether OCR data is available for pre-population"

    def ocr_data_available
      object.ocr_data_available?
    end

    # Story 4.4: Eligibility Verification fields
    field :eligible, Boolean, null: true, description: "Whether member is eligible for coverage"
    field :mental_health_covered, Boolean, null: true, description: "Whether mental health services are specifically covered"
    field :copay_amount, Float, null: true, description: "Copay amount for mental health services (USD)"
    field :deductible_amount, Float, null: true, description: "Deductible amount (USD)"
    field :deductible_met, Float, null: true, description: "Deductible amount already met (USD)"
    field :coinsurance_percentage, Integer, null: true, description: "Coinsurance percentage (0-100)"
    field :coverage_effective_date, GraphQL::Types::ISO8601Date, null: true, description: "Coverage effective date"
    field :coverage_termination_date, GraphQL::Types::ISO8601Date, null: true, description: "Coverage termination date"
    field :error_category, String, null: true, description: "Verification error category if failed"
    field :error_message, String, null: true, description: "Verification error message if failed"
    field :can_retry_verification, Boolean, null: false, description: "Whether verification can be retried"
    field :verified_at, GraphQL::Types::ISO8601DateTime, null: true, description: "When eligibility was verified"

    # Eligibility resolvers
    def eligible
      object.eligible?
    end

    def mental_health_covered
      object.mental_health_covered?
    end

    def copay_amount
      object.copay_amount
    end

    def deductible_amount
      object.deductible_amount
    end

    def deductible_met
      object.deductible_met
    end

    def coinsurance_percentage
      object.coinsurance_percentage
    end

    def coverage_effective_date
      object.coverage_effective_date
    end

    def coverage_termination_date
      object.coverage_termination_date
    end

    def error_category
      object.error_category
    end

    def error_message
      object.error_message
    end

    def can_retry_verification
      object.can_retry_verification?
    end

    def verified_at
      object.verified_at
    end

    # Story 4.5: Verification Status Display Fields
    field :verification_status_display, String, null: true,
          description: "User-friendly status: Verified, Needs Attention, Unable to Verify"
    field :verification_message, String, null: true,
          description: "Plain language explanation of status"
    field :why_explanation, String, null: true,
          description: "Detailed explanation of why this status occurred"
    field :coverage_details, Types::CoverageDetailsType, null: true,
          description: "Coverage information for verified insurance"
    field :next_steps, [String], null: false,
          description: "Array of action items for parent"
    field :can_retry, Boolean, null: false,
          description: "Whether verification can be retried (Story 4.5)"
    field :retry_attempts, Integer, null: false,
          description: "Number of retry attempts made"
    field :support_contact, Types::SupportContactType, null: true,
          description: "Support contact for complex issues"
    field :self_pay_option, Types::SelfPayOptionType, null: false,
          description: "Always available self-pay alternative"

    # Story 4.5: Status display resolvers
    def verification_status_display
      status_service.generate_display[:status_display]
    end

    def verification_message
      status_service.generate_display[:message]
    end

    def why_explanation
      status_service.generate_display[:why_explanation]
    end

    def next_steps
      status_service.generate_display[:next_steps]
    end

    def can_retry
      status_service.generate_display[:can_retry]
    end

    def support_contact
      status_service.generate_display[:support_contact]
    end

    def self_pay_option
      status_service.generate_display[:self_pay_option]
    end

    def coverage_details
      return nil unless object.verified?

      formatter = ::InsuranceServices::CoverageFormatter.new(object)
      formatter.format_all
    end

    private

    # Memoize status service for efficiency
    def status_service
      @status_service ||= ::InsuranceServices::StatusMessageService.new(object)
    end
  end
end
