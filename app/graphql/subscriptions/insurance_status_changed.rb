# frozen_string_literal: true

module Subscriptions
  # Subscribe to insurance status changes for a session
  #
  # Triggered when:
  # - OCR processing completes (ocr_complete or ocr_needs_review)
  # - OCR processing fails
  # - Eligibility verification status changes
  # - Progress updates during eligibility verification (Story 4.4)
  #
  # @example Subscribe in GraphQL
  #   subscription {
  #     insuranceStatusChanged(sessionId: "abc123") {
  #       insurance {
  #         id
  #         verificationStatus
  #         verificationResult
  #         ocrExtracted
  #         ocrConfidence
  #         needsReview
  #       }
  #       progress {
  #         percentage
  #         message
  #       }
  #     }
  #   }
  #
  # @see Story 4.2: OCR Insurance Card Extraction (AC7)
  # @see Story 4.4: Real-Time Eligibility Verification (AC9, AC10)
  class InsuranceStatusChanged < GraphQL::Schema::Subscription
    include GraphqlConcerns::SessionIdParser

    description "Subscribe to insurance status changes for a session"

    argument :session_id, ID, required: true, description: "The session ID to subscribe to"

    field :insurance, Types::InsuranceType, null: false, description: "The updated insurance record"
    field :progress, Types::VerificationProgressType, null: true,
      description: "Progress updates during eligibility verification"

    # Called when subscription is created
    #
    # @param session_id [String] The session ID to subscribe to
    # @return [Hash] Initial subscription payload
    def subscribe(session_id:)
      session = OnboardingSession.find(parse_session_id(session_id))
      insurance = session.insurance

      if insurance
        { insurance: insurance, progress: nil }
      else
        raise GraphQL::ExecutionError, "No insurance record for session"
      end
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError, "Session not found"
    end

    # Called when update is triggered
    #
    # Handles both formats:
    # - Hash with :insurance key (from OCR processing)
    # - Hash with :insurance and :progress keys (from eligibility verification)
    #
    # @param session_id [String] The session ID (from trigger)
    # @return [Hash] Updated subscription payload
    def update(session_id:)
      if object.is_a?(Hash)
        {
          insurance: object[:insurance],
          progress: object[:progress]
        }
      else
        # Direct insurance object (from older triggers)
        { insurance: object, progress: nil }
      end
    end
  end
end
