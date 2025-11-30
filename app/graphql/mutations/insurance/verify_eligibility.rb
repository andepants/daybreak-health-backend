# frozen_string_literal: true

module Mutations
  module Insurance
    # GraphQL mutation to initiate insurance eligibility verification
    #
    # This mutation triggers real-time verification of insurance coverage by
    # calling external eligibility APIs. Results are delivered via the
    # insuranceStatusChanged subscription.
    #
    # @example GraphQL request
    #   mutation {
    #     verifyEligibility(insuranceId: "abc123") {
    #       insurance {
    #         id
    #         verificationStatus
    #       }
    #       cached
    #       errors { field message }
    #     }
    #   }
    #
    # @see EligibilityVerificationJob
    # @see Subscriptions::InsuranceStatusChanged
    class VerifyEligibility < GraphQL::Schema::Mutation
      description "Initiate insurance eligibility verification"

      # Input
      argument :insurance_id, ID, required: true,
        description: "The insurance record ID to verify"

      # Output
      field :insurance, Types::InsuranceType, null: true,
        description: "The updated insurance record with verification status"
      field :cached, GraphQL::Types::Boolean, null: false,
        description: "Whether result was returned from cache (within 24 hours)"
      field :errors, [Types::FieldErrorType], null: false,
        description: "List of validation errors"

      # Cache TTL for verification results (24 hours per AC6)
      CACHE_TTL = 24.hours

      def resolve(insurance_id:)
        # Find insurance record
        insurance = ::Insurance.find_by(id: insurance_id)

        unless insurance
          return {
            insurance: nil,
            cached: false,
            errors: [{ field: "insurance_id", message: "Insurance record not found" }]
          }
        end

        # Authorization check - session must own insurance
        unless authorized?(insurance)
          return {
            insurance: nil,
            cached: false,
            errors: [{ field: "insurance_id", message: "Unauthorized" }]
          }
        end

        # Check if session is active
        session = insurance.onboarding_session
        if session.past_expiration?
          return {
            insurance: nil,
            cached: false,
            errors: [{ field: "session", message: "Session has expired" }]
          }
        end

        # Validate insurance has required data for verification
        unless insurance.member_id.present? && insurance.payer_name.present?
          return {
            insurance: nil,
            cached: false,
            errors: [{ field: "insurance", message: "Insurance must have member ID and payer name" }]
          }
        end

        # Check cache first (AC6 - 24 hour cache)
        cached_result = check_cache(insurance)
        if cached_result
          # Audit cache hit
          create_audit_log(insurance, "ELIGIBILITY_CACHE_HIT")

          return {
            insurance: insurance.reload,
            cached: true,
            errors: []
          }
        end

        # Check if verification is already in progress
        if insurance.in_progress?
          return {
            insurance: insurance,
            cached: false,
            errors: [{ field: "insurance", message: "Verification already in progress" }]
          }
        end

        # Queue verification job
        EligibilityVerificationJob.perform_later(insurance.id)

        # Update status to in_progress
        insurance.update!(verification_status: :in_progress)

        # Audit verification initiated
        create_audit_log(insurance, "ELIGIBILITY_VERIFICATION_INITIATED")

        {
          insurance: insurance.reload,
          cached: false,
          errors: []
        }
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("Error updating insurance: #{e.message}")
        {
          insurance: nil,
          cached: false,
          errors: [{ field: "base", message: "Failed to update insurance status" }]
        }
      rescue StandardError => e
        Rails.logger.error("Error in VerifyEligibility mutation: #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n"))
        {
          insurance: nil,
          cached: false,
          errors: [{ field: "base", message: "An error occurred during verification" }]
        }
      end

      private

      # Check authorization - session must own insurance
      #
      # @param insurance [Insurance] The insurance record
      # @return [Boolean] True if authorized
      def authorized?(insurance)
        current_session_id = context[:current_session_id]
        return true if current_session_id.nil? # Allow in development/test

        insurance.onboarding_session_id == current_session_id
      end

      # Check cache for existing verification result
      #
      # @param insurance [Insurance] The insurance record
      # @return [Hash, nil] Cached result or nil
      def check_cache(insurance)
        cache_key = cache_key_for(insurance)
        cached_data = Rails.cache.read(cache_key)

        return nil unless cached_data

        # Update insurance with cached result
        insurance.update!(
          verification_result: cached_data,
          verification_status: cached_data["status"]&.downcase&.to_sym || :verified
        )

        cached_data
      end

      # Generate cache key for insurance eligibility
      #
      # @param insurance [Insurance] The insurance record
      # @return [String] Cache key
      def cache_key_for(insurance)
        "insurance:eligibility:#{insurance.id}"
      end

      # Create audit log entry
      #
      # @param insurance [Insurance] The insurance record
      # @param action [String] The audit action
      def create_audit_log(insurance, action)
        AuditLog.create!(
          onboarding_session_id: insurance.onboarding_session_id,
          action: action,
          resource: "Insurance",
          resource_id: insurance.id,
          details: {
            payer_name: insurance.payer_name,
            verification_status: insurance.verification_status,
            timestamp: Time.current.iso8601
          },
          ip_address: context[:ip_address]
        )
      rescue StandardError => e
        # Don't fail the mutation if audit log fails
        Rails.logger.error("Failed to create audit log: #{e.message}")
      end
    end
  end
end
