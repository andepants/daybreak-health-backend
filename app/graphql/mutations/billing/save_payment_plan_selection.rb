# frozen_string_literal: true

module Mutations
  module Billing
    # Save payment plan selection mutation
    #
    # Creates a PaymentPlan record linked to OnboardingSession to store the parent's
    # payment plan selection for future billing integration.
    #
    # Note: Actual payment processing is post-MVP. This mutation only stores the selection.
    #
    # AC 6.5.8: Payment plan selection is stored for billing integration
    class SavePaymentPlanSelection < BaseMutation
      description "Save payment plan selection for billing integration (no payment processing)"

      # Arguments
      argument :session_id, ID, required: true,
               description: "Session ID to link payment plan to"

      argument :plan_duration_months, Integer, required: true,
               description: "Selected plan duration in months (0 for upfront)"

      argument :monthly_amount, Float, required: true,
               description: "Monthly payment amount in USD"

      argument :total_amount, Float, required: true,
               description: "Total cost in USD"

      argument :discount_applied, Float, required: false,
               description: "Discount amount applied in USD (optional)"

      argument :payment_method_preference, Types::PaymentMethodEnum, required: true,
               description: "Preferred payment method"

      # Return fields
      field :payment_plan, Types::PaymentPlanType, null: false,
            description: "Created payment plan"

      field :success, Boolean, null: false,
            description: "Whether the operation succeeded"

      field :message, String, null: true,
            description: "Success or error message"

      def resolve(session_id:, plan_duration_months:, monthly_amount:, total_amount:,
                  payment_method_preference:, discount_applied: 0.0)
        # Normalize session ID
        actual_id = normalize_session_id(session_id)

        # Load session
        session = OnboardingSession.find(actual_id)

        # Verify user has access to this session
        unless current_session && current_session.id == session.id
          raise GraphQL::ExecutionError.new(
            "Access denied",
            extensions: {
              code: "UNAUTHENTICATED",
              timestamp: Time.current.iso8601
            }
          )
        end

        # Map GraphQL enum value to model enum value
        payment_method = payment_method_preference.downcase

        # Create payment plan
        payment_plan = PaymentPlan.create!(
          onboarding_session: session,
          plan_duration_months: plan_duration_months,
          monthly_amount: monthly_amount,
          total_amount: total_amount,
          discount_applied: discount_applied,
          payment_method_preference: payment_method,
          status: :pending
        )

        # Create audit log
        create_audit_log(session, payment_plan)

        {
          payment_plan: payment_plan,
          success: true,
          message: "Payment plan selection saved successfully"
        }
      rescue ActiveRecord::RecordNotFound
        raise GraphQL::ExecutionError.new(
          "Session not found",
          extensions: {
            code: "NOT_FOUND",
            timestamp: Time.current.iso8601
          }
        )
      rescue ActiveRecord::RecordInvalid => e
        raise GraphQL::ExecutionError.new(
          "Invalid payment plan: #{e.message}",
          extensions: {
            code: "INVALID_INPUT",
            timestamp: Time.current.iso8601
          }
        )
      end

      private

      # Normalize session ID by converting sess_ prefix to UUID format
      #
      # @param session_id [String] Session ID (either UUID or sess_ prefixed)
      # @return [String] UUID formatted session ID
      def normalize_session_id(session_id)
        if session_id.start_with?("sess_")
          hex = session_id.sub("sess_", "")
          # Convert 32-char hex to UUID format: 8-4-4-4-12
          "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
        else
          session_id
        end
      end

      # Create audit log for payment plan selection
      #
      # @param session [OnboardingSession] The session
      # @param payment_plan [PaymentPlan] The created payment plan
      def create_audit_log(session, payment_plan)
        AuditLog.create!(
          onboarding_session_id: session.id,
          action: "PAYMENT_PLAN_SELECTED",
          resource: "PaymentPlan",
          resource_id: payment_plan.id.to_s,
          details: {
            plan_duration_months: payment_plan.plan_duration_months,
            monthly_amount: payment_plan.monthly_amount.to_s,
            total_amount: payment_plan.total_amount.to_s,
            discount_applied: payment_plan.discount_applied.to_s,
            payment_method_preference: payment_plan.payment_method_preference,
            timestamp: Time.current.iso8601
          },
          ip_address: context[:ip_address],
          user_agent: context[:user_agent]
        )
      end

      # Get current session from context
      #
      # @return [OnboardingSession, nil]
      def current_session
        context[:current_session]
      end
    end
  end
end
