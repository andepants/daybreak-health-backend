# frozen_string_literal: true

module Mutations
  module Insurance
    # Mutation to select self-pay option
    #
    # Sets insurance verification_status to :self_pay, indicating
    # the parent has chosen to bypass insurance and pay out-of-pocket.
    class SelectSelfPay < BaseMutation
      include GraphqlConcerns::CurrentSession
      include GraphqlConcerns::SessionIdParser

      description "Select self-pay option for a session"

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

        # Create or update insurance record with self_pay status
        insurance = session.insurance || session.build_insurance

        # Set verification status to self_pay and store verification timestamp
        insurance.verification_status = :self_pay
        insurance.verification_result = (insurance.verification_result || {}).merge(
          "verified_at" => Time.current.iso8601
        )
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
