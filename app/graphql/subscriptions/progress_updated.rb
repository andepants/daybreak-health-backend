# frozen_string_literal: true

module Subscriptions
  # Subscription for real-time progress updates
  #
  # Clients subscribe to progress updates for a specific session.
  # Updates are triggered when session progress changes via UpdateSessionProgress mutation.
  class ProgressUpdated < GraphQL::Schema::Subscription
    description "Subscribe to progress updates for a specific session"

    argument :session_id, ID, required: true, description: "The session ID to subscribe to"

    field :percentage, Integer, null: false, description: "Progress percentage (0-100)"
    field :current_phase, String, null: false, description: "Current phase in onboarding flow"
    field :completed_phases, [String], null: false, description: "Array of completed phase names"
    field :next_phase, String, null: true, description: "Next phase in sequence (null if at end)"
    field :estimated_minutes_remaining, Integer, null: false, description: "Estimated minutes remaining"

    # Called when subscription is created
    # AC6: Authorization check - verify session exists and client has access
    def subscribe(session_id:)
      # Verify session exists
      session = OnboardingSession.find(session_id)

      # Calculate initial progress
      progress = Conversation::ProgressService.new(session).calculate

      # Return initial progress data
      {
        percentage: progress[:percentage],
        current_phase: progress[:current_phase],
        completed_phases: progress[:completed_phases],
        next_phase: progress[:next_phase],
        estimated_minutes_remaining: progress[:estimated_minutes_remaining]
      }
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError, "Session not found"
    end

    # Called when update is triggered
    # The progress data is passed as the object from the trigger
    def update(session_id:)
      # object contains the progress hash passed from trigger
      {
        percentage: object[:percentage],
        current_phase: object[:current_phase],
        completed_phases: object[:completed_phases],
        next_phase: object[:next_phase],
        estimated_minutes_remaining: object[:estimated_minutes_remaining]
      }
    end
  end
end
