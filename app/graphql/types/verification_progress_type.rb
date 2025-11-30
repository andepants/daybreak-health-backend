# frozen_string_literal: true

module Types
  # GraphQL type for eligibility verification progress updates
  #
  # Used by InsuranceStatusChanged subscription to provide real-time
  # progress updates during eligibility verification (Story 4.4, AC10).
  #
  # Progress stages:
  # - 0%:   Job started - "Contacting insurance company..."
  # - 33%:  API called - "Checking coverage..."
  # - 66%:  Parsing results - "Processing response..."
  # - 100%: Complete - "Verification complete"
  #
  # @example GraphQL subscription response
  #   {
  #     "data": {
  #       "insuranceStatusChanged": {
  #         "progress": {
  #           "percentage": 33,
  #           "message": "Checking coverage..."
  #         }
  #       }
  #     }
  #   }
  class VerificationProgressType < Types::BaseObject
    description "Progress updates during eligibility verification"

    field :percentage, Integer, null: false,
      description: "Progress percentage (0, 33, 66, or 100)"

    field :message, String, null: false,
      description: "User-friendly progress message"
  end
end
