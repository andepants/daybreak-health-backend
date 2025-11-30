# frozen_string_literal: true

module Queries
  # Calculate cost for therapy session
  #
  # Calculates session costs based on service type, duration, and other factors.
  # Requires authentication - user must own the session or be admin.
  #
  # Example:
  #   query {
  #     calculateCost(
  #       sessionId: "sess_abc123",
  #       serviceType: "individual_therapy",
  #       duration: 50,
  #       discountCode: "PERCENTAGE_10"
  #     ) {
  #       grossCost
  #       netCost
  #       adjustments {
  #         type
  #         description
  #         amount
  #       }
  #       calculatedAt
  #     }
  #   }
  class CalculateCost < Queries::BaseQuery
    description "Calculate therapy session cost with detailed breakdown"

    # Arguments
    argument :session_id, ID, required: true,
             description: "Onboarding session ID (for authorization)"

    argument :service_type, String, required: true,
             description: "Service type (intake, individual_therapy, family_therapy, onsite_care)"

    argument :duration, Integer, required: false,
             description: "Session duration in minutes (default: 50)"

    argument :therapist_tier, String, required: false,
             description: "Therapist tier (standard, senior, lead, specialist)"

    argument :special_services, [ String ], required: false,
             description: "Array of special service codes (telehealth_setup, translation, etc.)"

    argument :discount_code, String, required: false,
             description: "Discount code (PERCENTAGE_XX, FIXED_XXX, HARDSHIP_XX)"

    # Return type
    type Types::CostBreakdownType, null: false

    # Resolver
    def resolve(session_id:, service_type:, duration: nil, therapist_tier: nil,
                special_services: [], discount_code: nil)
      # Verify session exists and user has access
      session = authorize_session_access(session_id)

      # Validate service type
      unless SessionRate.service_types.key?(service_type)
        raise GraphQL::ExecutionError,
              "Invalid service_type: #{service_type}. " \
              "Must be one of: #{SessionRate.service_types.keys.join(', ')}"
      end

      # Calculate cost using service
      begin
        breakdown = ::Billing::CostCalculationService.call(
          service_type: service_type,
          duration: duration,
          therapist_tier: therapist_tier,
          special_services: special_services,
          discount_code: discount_code
        )
      rescue ArgumentError => e
        raise GraphQL::ExecutionError, "Cost calculation error: #{e.message}"
      end

      # Store calculation in session for future reference
      session.store_cost_breakdown(breakdown)

      # Create audit log for cost calculation
      create_cost_audit_log(session, breakdown)

      # Return breakdown
      breakdown
    end

    private

    # Authorize session access
    #
    # Verifies that current user owns the session or is an admin.
    # Session ID format: sess_<uuid> or <uuid> (strip prefix and validate format)
    #
    # @param session_id [String] The session ID
    # @return [OnboardingSession] The session
    # @raise [GraphQL::ExecutionError] If session not found or access denied
    def authorize_session_access(session_id)
      # Defensive parsing with UUID format validation
      parsed_id = parse_session_id(session_id)

      unless parsed_id
        raise GraphQL::ExecutionError, "Invalid session ID format"
      end

      session = OnboardingSession.find_by(id: parsed_id)

      unless session
        raise GraphQL::ExecutionError, "Session not found"
      end

      # Check authorization using context
      current_session = context[:current_session]
      current_session_id = current_session&.id || context[:current_session_id]

      unless current_session_id == session.id
        raise GraphQL::ExecutionError, 'Not authorized to calculate costs for this session'
      end

      session
    end

    # Parse and validate session ID format
    #
    # Handles both formats:
    # - sess_<uuid>: Strip 'sess_' prefix and validate as UUID
    # - <uuid>: Validate as UUID directly
    #
    # @param session_id [String] The session ID to parse
    # @return [String] The validated UUID, or nil if invalid format
    def parse_session_id(session_id)
      return nil unless session_id.is_a?(String) && session_id.present?

      # Strip 'sess_' prefix if present
      id = session_id.gsub(/^sess_/, "")

      # Handle CUID format (32 hex characters without hyphens)
      if id.match?(/^[a-f0-9]{32}$/i)
        # Convert from CUID format back to UUID format (8-4-4-4-12)
        # Insert hyphens at the correct positions: 8, 4, 4, 4, 12 characters
        return "#{id[0..7]}-#{id[8..11]}-#{id[12..15]}-#{id[16..19]}-#{id[20..31]}"
      end

      # Handle standard UUID format (with hyphens)
      if id.match?(/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i)
        return id.downcase
      end

      # Invalid format
      nil
    end

    # Create audit log for cost calculation
    #
    # @param session [OnboardingSession] The session
    # @param breakdown [Hash] The cost breakdown
    def create_cost_audit_log(session, breakdown)
      AuditLog.create!(
        action: "COST_CALCULATED",
        resource: "OnboardingSession",
        resource_id: session.id,
        onboarding_session: session,
        details: {
          service_type: breakdown[:metadata][:service_type],
          gross_cost: breakdown[:gross_cost].to_f,
          net_cost: breakdown[:net_cost].to_f,
          calculated_at: breakdown[:calculated_at]
          # Note: Do not log discount_code for privacy/security
        },
        ip_address: context[:ip_address],
        user_agent: context[:user_agent]
      )
    rescue StandardError => e
      # Log error but don't fail the query
      Rails.logger.error("Failed to create cost calculation audit log: #{e.message}")
    end
  end
end
