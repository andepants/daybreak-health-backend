# frozen_string_literal: true

module Mutations
  module Insurance
    # Mutation to switch from self-pay back to insurance
    #
    # Reverts verification_status from :self_pay to :pending or :unverified
    # to allow parent to re-enter and verify insurance information.
    class SwitchToInsurance < BaseMutation
      include GraphqlConcerns::CurrentSession
      include GraphqlConcerns::SessionIdParser

      description "Switch from self-pay back to insurance verification"

      argument :session_id, ID, required: true, description: "Session ID"

      field :session, Types::OnboardingSessionType, null: false
      field :success, Boolean, null: false

      def resolve(session_id:)
        # Parse session ID to UUID format
        actual_id = parse_session_id(session_id)

        # Load session
        session = OnboardingSession.find(actual_id)

        # Verify authorization
        unless current_session && current_session.id == session.id
          raise GraphQL::ExecutionError.new(
            "Access denied",
            extensions: {
              code: "UNAUTHENTICATED",
              timestamp: Time.current.iso8601
            }
          )
        end

        # Get or create insurance record
        insurance = session.insurance

        unless insurance
          raise GraphQL::ExecutionError.new(
            "No insurance record found",
            extensions: {
              code: "NOT_FOUND",
              timestamp: Time.current.iso8601
            }
          )
        end

        # Revert from self_pay to appropriate status
        # If insurance info exists, set to pending for re-verification
        # Otherwise, set to failed (needs new info)
        if insurance.payer_name.present? || insurance.member_id.present?
          insurance.verification_status = :pending
        else
          insurance.verification_status = :failed
        end

        # Clear verification timestamp
        insurance.verification_result = (insurance.verification_result || {}).except("verified_at")
        insurance.save!

        {
          session: session.reload,
          success: true
        }
      rescue ActiveRecord::RecordNotFound
        raise GraphQL::ExecutionError.new(
          "Session not found",
          extensions: {
            code: "NOT_FOUND",
            timestamp: Time.current.iso8601
          }
        )
      end
    end
  end
end
