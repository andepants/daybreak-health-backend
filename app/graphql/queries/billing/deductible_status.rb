# frozen_string_literal: true

module Queries
  module Billing
    # GraphQL query to retrieve deductible status for a session's insurance
    #
    # Story 6.4: Deductible & Out-of-Pocket Tracking
    # Returns comprehensive deductible and OOP tracking information including:
    # - Deductible amount, met, and remaining
    # - OOP max amount, met, and remaining
    # - Family vs individual plan distinction
    # - Session projections until deductible met
    # - Plan year reset dates
    # - Progress percentages
    #
    # Example query:
    #   query {
    #     deductibleStatus(sessionId: "sess_123") {
    #       deductibleAmount
    #       deductibleMet
    #       deductibleRemaining
    #       oopMaxAmount
    #       oopMet
    #       oopRemaining
    #       isFamilyPlan
    #       yearResetDate
    #       progressPercentage
    #       sessionsUntilDeductibleMet
    #       dataSource
    #       lastUpdatedAt
    #     }
    #   }
    #
    class DeductibleStatus < Queries::BaseQuery
      include GraphqlConcerns::CurrentSession

      type Types::DeductibleStatusType, null: true

      argument :session_id, ID, required: true,
               description: "ID of the onboarding session with insurance to track"

      # Resolve the query
      #
      # @param session_id [String] The onboarding session ID
      # @return [Hash, nil] Deductible status or nil if insurance not verified
      def resolve(session_id:)
        # Find the onboarding session
        session = OnboardingSession.find_by(id: session_id)
        raise GraphQL::ExecutionError, "Session not found" unless session

        # Authorize access - verify current session matches requested session
        current_session_id = context[:current_session]&.id || context[:current_session_id]
        unless current_session_id == session.id
          raise GraphQL::ExecutionError.new(
            "Access denied",
            extensions: { code: "UNAUTHENTICATED", timestamp: Time.current.iso8601 }
          )
        end

        # Find insurance for session
        insurance = session.insurance
        unless insurance
          raise GraphQL::ExecutionError.new(
            "No insurance found for session",
            extensions: {
              code: "NOT_FOUND",
              timestamp: Time.current.iso8601
            }
          )
        end

        # Check if verified
        unless insurance.eligibility_verified?
          raise GraphQL::ExecutionError.new(
            "Insurance must be verified before checking deductible status",
            extensions: {
              code: "UNVERIFIED_INSURANCE",
              status: insurance.verification_status,
              timestamp: Time.current.iso8601
            }
          )
        end

        # Call the deductible tracker service
        begin
          tracker = ::Billing::DeductibleTracker.new(insurance: insurance)
          status = tracker.current_status

          # Log audit event
          log_deductible_status_accessed(insurance, session)

          status
        rescue StandardError => e
          Rails.logger.error("Deductible status failed: #{e.class} - #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          raise GraphQL::ExecutionError, "Failed to retrieve deductible status"
        end
      end

      private

      # Log audit event for deductible status access
      #
      # @param insurance [Insurance] The insurance record
      # @param session [OnboardingSession] The session
      def log_deductible_status_accessed(insurance, session)
        AuditLog.create!(
          onboarding_session_id: session.id,
          action: "DEDUCTIBLE_STATUS_ACCESSED",
          resource: "Insurance",
          details: {
            insurance_id: insurance.id,
            timestamp: Time.current.iso8601
          }
        )
      rescue StandardError => e
        Rails.logger.warn("Failed to log audit event: #{e.message}")
      end
    end
  end
end
