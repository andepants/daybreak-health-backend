# frozen_string_literal: true

module Subscriptions
  class SessionUpdated < GraphQL::Schema::Subscription
    description "Subscribe to updates for a specific session"

    argument :session_id, ID, required: true, description: "The session ID to subscribe to"

    field :session, Types::OnboardingSessionType, null: false, description: "The updated session"

    # Called when subscription is created
    def subscribe(session_id:)
      # Verify session exists
      session = OnboardingSession.find(session_id)
      { session: session }
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError, "Session not found"
    end

    # Called when update is triggered
    def update(session_id:)
      # The session is passed as the object from the trigger
      { session: object }
    end
  end
end
