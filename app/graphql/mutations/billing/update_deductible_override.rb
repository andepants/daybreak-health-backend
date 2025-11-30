# frozen_string_literal: true

module Mutations
  module Billing
    # Mutation to manually override deductible and OOP tracking data
    #
    # Story 6.4: Deductible & Out-of-Pocket Tracking (AC6)
    # Allows manual entry of deductible data when eligibility API data is unavailable
    # or incorrect. All overrides are audited with timestamp, user, and reason.
    #
    # Example mutation:
    #   mutation {
    #     updateDeductibleOverride(
    #       sessionId: "sess_123",
    #       deductibleMet: 150.00,
    #       oopMet: 200.00,
    #       overrideReason: "Patient provided updated EOB"
    #     ) {
    #       insurance {
    #         id
    #         verificationStatus
    #       }
    #       errors
    #     }
    #   }
    #
    class UpdateDeductibleOverride < Mutations::BaseMutation
      include GraphqlConcerns::CurrentSession

      description "Manually override deductible and OOP tracking data with audit trail"

      # Input fields
      argument :session_id, ID, required: true,
               description: "Onboarding session ID"

      argument :deductible_met, Float, required: false,
               description: "Amount of deductible met (optional - keeps existing if not provided)"

      argument :oop_met, Float, required: false,
               description: "Amount of OOP max met (optional - keeps existing if not provided)"

      argument :deductible_amount, Float, required: false,
               description: "Total deductible amount (optional - override total if provided)"

      argument :oop_max_amount, Float, required: false,
               description: "Total OOP max amount (optional - override total if provided)"

      argument :override_reason, String, required: true,
               description: "Reason for manual override (required for audit trail)"

      # Return fields
      field :insurance, Types::InsuranceType, null: true,
            description: "Updated insurance record"

      field :errors, [ String ], null: false,
            description: "List of errors if update failed"

      # Perform the mutation
      #
      # @param session_id [String] The onboarding session ID
      # @param deductible_met [Float] Deductible met amount
      # @param oop_met [Float] OOP met amount
      # @param deductible_amount [Float] Total deductible amount (optional override)
      # @param oop_max_amount [Float] Total OOP max amount (optional override)
      # @param override_reason [String] Reason for override
      # @return [Hash] Result with insurance record or errors
      def resolve(session_id:, override_reason:, **overrides)
        # Find the onboarding session
        session = OnboardingSession.find_by(id: session_id)
        unless session
          return {
            insurance: nil,
            errors: [ "Session not found" ]
          }
        end

        # Authorize access - verify current session matches requested session
        current_session_id = context[:current_session]&.id || context[:current_session_id]
        unless current_session_id == session.id
          return {
            insurance: nil,
            errors: [ "Access denied" ]
          }
        end

        # Find insurance for session
        insurance = session.insurance
        unless insurance
          return {
            insurance: nil,
            errors: [ "No insurance found for session" ]
          }
        end

        # Validate override reason
        if override_reason.blank?
          return {
            insurance: nil,
            errors: [ "Override reason is required" ]
          }
        end

        # Validate input values
        validation_errors = validate_override_values(overrides)
        if validation_errors.any?
          return {
            insurance: nil,
            errors: validation_errors
          }
        end

        # Apply the override
        begin
          # Capture previous values for audit trail
          previous_values = capture_previous_values(insurance)

          apply_override(insurance, overrides, override_reason)

          # Log audit event with previous values
          log_deductible_override(insurance, session, overrides, override_reason, previous_values)

          {
            insurance: insurance,
            errors: []
          }
        rescue StandardError => e
          Rails.logger.error("Deductible override failed: #{e.class} - #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          {
            insurance: nil,
            errors: [ "Failed to update deductible override: #{e.message}" ]
          }
        end
      end

      private

      # Apply the deductible override to the insurance record
      #
      # @param insurance [Insurance] The insurance record
      # @param overrides [Hash] Override values
      # @param reason [String] Override reason
      def apply_override(insurance, overrides, reason)
        result = insurance.verification_result || {}
        override_data = result["deductible_override"] || {}

        # Update override fields (only if provided)
        override_data["deductible_met"] = overrides[:deductible_met] if overrides[:deductible_met].present?
        override_data["oop_met"] = overrides[:oop_met] if overrides[:oop_met].present?
        override_data["deductible_amount"] = overrides[:deductible_amount] if overrides[:deductible_amount].present?
        override_data["oop_max_amount"] = overrides[:oop_max_amount] if overrides[:oop_max_amount].present?

        # Add audit metadata
        override_data["override_timestamp"] = Time.current.iso8601
        override_data["override_by"] = current_session&.id
        override_data["override_reason"] = reason
        override_data["source"] = "manual"

        # Store in verification_result
        result["deductible_override"] = override_data
        insurance.update!(verification_result: result)
      end

      # Validate override values
      #
      # @param overrides [Hash] Override values to validate
      # @return [Array<String>] Array of validation error messages
      def validate_override_values(overrides)
        errors = []
        max_reasonable_value = 1_000_000.0 # $1M is reasonable max for medical costs

        # Validate deductible_met
        if overrides[:deductible_met].present?
          value = overrides[:deductible_met]
          if value < 0
            errors << "Deductible met cannot be negative"
          elsif value > max_reasonable_value
            errors << "Deductible met exceeds reasonable maximum ($#{max_reasonable_value.to_i})"
          end
        end

        # Validate oop_met
        if overrides[:oop_met].present?
          value = overrides[:oop_met]
          if value < 0
            errors << "OOP met cannot be negative"
          elsif value > max_reasonable_value
            errors << "OOP met exceeds reasonable maximum ($#{max_reasonable_value.to_i})"
          end
        end

        # Validate deductible_amount
        if overrides[:deductible_amount].present?
          value = overrides[:deductible_amount]
          if value < 0
            errors << "Deductible amount cannot be negative"
          elsif value > max_reasonable_value
            errors << "Deductible amount exceeds reasonable maximum ($#{max_reasonable_value.to_i})"
          end
        end

        # Validate oop_max_amount
        if overrides[:oop_max_amount].present?
          value = overrides[:oop_max_amount]
          if value < 0
            errors << "OOP max amount cannot be negative"
          elsif value > max_reasonable_value
            errors << "OOP max amount exceeds reasonable maximum ($#{max_reasonable_value.to_i})"
          end
        end

        # Validate logical consistency: met <= amount
        if overrides[:deductible_met].present? && overrides[:deductible_amount].present?
          if overrides[:deductible_met] > overrides[:deductible_amount]
            errors << "Deductible met cannot exceed deductible amount"
          end
        end

        if overrides[:oop_met].present? && overrides[:oop_max_amount].present?
          if overrides[:oop_met] > overrides[:oop_max_amount]
            errors << "OOP met cannot exceed OOP max amount"
          end
        end

        errors
      end

      # Capture previous values for audit trail
      #
      # @param insurance [Insurance] The insurance record
      # @return [Hash] Previous override values
      def capture_previous_values(insurance)
        result = insurance.verification_result || {}
        override_data = result["deductible_override"] || {}

        {
          deductible_met: override_data["deductible_met"],
          oop_met: override_data["oop_met"],
          deductible_amount: override_data["deductible_amount"],
          oop_max_amount: override_data["oop_max_amount"],
          override_timestamp: override_data["override_timestamp"],
          override_by: override_data["override_by"],
          override_reason: override_data["override_reason"]
        }
      end

      # Log audit event for deductible override
      #
      # @param insurance [Insurance] The insurance record
      # @param session [OnboardingSession] The session
      # @param overrides [Hash] Override values
      # @param reason [String] Override reason
      # @param previous_values [Hash] Previous override values
      def log_deductible_override(insurance, session, overrides, reason, previous_values)
        AuditLog.create!(
          onboarding_session_id: session.id,
          action: "DEDUCTIBLE_OVERRIDE",
          resource: "Insurance",
          details: {
            insurance_id: insurance.id,
            override_reason: reason,
            fields_updated: overrides.keys,
            new_values: overrides,
            previous_values: previous_values,
            timestamp: Time.current.iso8601,
            session_id: session.id,
            performed_by: current_session&.id
          }
        )
      rescue StandardError => e
        Rails.logger.warn("Failed to log audit event: #{e.message}")
      end
    end
  end
end
