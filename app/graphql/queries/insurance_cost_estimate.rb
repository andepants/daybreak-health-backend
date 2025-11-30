# frozen_string_literal: true

module Queries
  # GraphQL query to retrieve cost estimate for a session's insurance
  #
  # Returns cost breakdown including insurance payment, patient responsibility,
  # deductible status, and any coverage limitations.
  #
  # Example query:
  #   query {
  #     insuranceCostEstimate(sessionId: "123") {
  #       insurancePays
  #       patientPays
  #       allowedAmount
  #       billedAmount
  #       deductibleStatus {
  #         amount
  #         met
  #         remaining
  #         isMet
  #       }
  #       coverageLimitations
  #       isEstimate
  #       disclaimer
  #     }
  #   }
  #
  class InsuranceCostEstimate < Queries::BaseQuery
    include GraphqlConcerns::CurrentSession

    type Types::CostEstimateType, null: true

    argument :session_id, ID, required: true,
             description: "ID of the onboarding session with insurance to estimate"

    argument :service_type, String, required: false,
             description: "Type of service (default: individual_therapy)"

    # Resolve the query
    #
    # @param session_id [String] The onboarding session ID
    # @param service_type [String] Optional service type
    # @return [Hash, nil] Cost estimate or nil if insurance not verified
    def resolve(session_id:, service_type: "individual_therapy")
      # H1 FIX: Check authentication first before any database queries
      unless current_session
        raise GraphQL::ExecutionError.new(
          "Authentication required",
          extensions: {
            code: "UNAUTHENTICATED",
            timestamp: Time.current.iso8601
          }
        )
      end

      # M5 FIX: Validate service_type input using whitelist
      validate_service_type!(service_type)

      # Find the onboarding session
      session = OnboardingSession.find_by(id: session_id)

      # H1 FIX: Use constant-time comparison and don't reveal session existence
      unless session && secure_compare(current_session.id.to_s, session.id.to_s)
        raise GraphQL::ExecutionError.new(
          "Access denied",
          extensions: {
            code: "UNAUTHORIZED",
            timestamp: Time.current.iso8601
          }
        )
      end

      # Find insurance for session
      insurance = session.insurance
      unless insurance
        # M1 FIX: More specific error type
        raise GraphQL::ExecutionError.new(
          "No insurance found for session",
          extensions: {
            code: "INSURANCE_NOT_FOUND",
            timestamp: Time.current.iso8601
          }
        )
      end

      # Check if verified
      unless insurance.eligibility_verified?
        return nil # Return null if not verified
      end

      # Call the insurance estimate service
      begin
        estimate = ::Billing::InsuranceEstimateService.call(
          insurance: insurance,
          service_type: service_type
        )

        # Log audit event
        log_cost_estimate_requested(insurance, session)

        estimate
      rescue ArgumentError => e
        # M1 FIX: More specific error type
        raise GraphQL::ExecutionError.new(
          "Cannot calculate estimate: #{e.message}",
          extensions: {
            code: "INVALID_ESTIMATE_REQUEST",
            timestamp: Time.current.iso8601
          }
        )
      rescue StandardError => e
        Rails.logger.error("Insurance cost estimate failed: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        # M1 FIX: More specific error type
        raise GraphQL::ExecutionError.new(
          "Failed to calculate cost estimate",
          extensions: {
            code: "ESTIMATE_CALCULATION_FAILED",
            timestamp: Time.current.iso8601
          }
        )
      end
    end

    private

    # Allowed service types (whitelist for input validation)
    ALLOWED_SERVICE_TYPES = %w[
      individual_therapy
      family_therapy
      group_therapy
      couples_therapy
      psychiatric_evaluation
      medication_management
    ].freeze

    # Validate service_type input against whitelist
    #
    # @param service_type [String] The service type to validate
    # @raise [GraphQL::ExecutionError] If service type is invalid
    def validate_service_type!(service_type)
      unless ALLOWED_SERVICE_TYPES.include?(service_type)
        raise GraphQL::ExecutionError.new(
          "Invalid service type",
          extensions: {
            code: "INVALID_SERVICE_TYPE",
            allowed_values: ALLOWED_SERVICE_TYPES,
            timestamp: Time.current.iso8601
          }
        )
      end
    end

    # Constant-time string comparison to prevent timing attacks
    #
    # @param a [String] First string
    # @param b [String] Second string
    # @return [Boolean] True if strings match
    def secure_compare(a, b)
      return false if a.nil? || b.nil?
      return false unless a.bytesize == b.bytesize

      l = a.unpack "C#{a.bytesize}"

      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res.zero?
    end

    # Log audit event for cost estimate request
    #
    # @param insurance [Insurance] The insurance record
    # @param session [OnboardingSession] The session
    def log_cost_estimate_requested(insurance, session)
      return unless insurance.respond_to?(:create_audit_event)

      insurance.create_audit_event(
        action: "COST_ESTIMATE_REQUESTED",
        actor: current_session,
        details: {
          insurance_id: insurance.id,
          session_id: session.id
          # Note: Do NOT log actual coverage amounts (PHI-safe)
        }
      )
    rescue StandardError => e
      Rails.logger.warn("Failed to log audit event: #{e.message}")
    end
  end
end
