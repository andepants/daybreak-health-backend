# frozen_string_literal: true

module Mutations
  module Sessions
    # UpdateSessionProgress - Updates session progress with deep merge and extends expiration
    #
    # Progress Structure (JSONB):
    # The progress field stores session progress as a JSON object with the following structure:
    #
    # {
    #   "currentStep": "parent_info",           # Current step in the onboarding flow (string, required)
    #   "completedSteps": ["welcome", "terms"], # Array of completed step names (array, required)
    #   "intake": {                             # Parent and child information section (object, optional)
    #     "parentInfoComplete": true,           # Parent info completion status (boolean)
    #     "childInfoComplete": false            # Child info completion status (boolean)
    #   },
    #   "insurance": {                          # Insurance verification section (object, optional)
    #     "cardUploaded": false,                # Insurance card upload status (boolean)
    #     "verificationStatus": null            # Verification status: null | "pending" | "verified" | "failed"
    #   },
    #   "assessment": {                         # Mental health assessment section (object, optional)
    #     "screeningComplete": false,           # Screening questionnaire status (boolean)
    #     "riskFlags": []                       # Array of risk indicators (array of strings)
    #   }
    # }
    #
    # Merge Behavior:
    # - Deep merges new progress with existing progress (preserves nested data)
    # - Arrays in completedSteps are merged and deduplicated
    # - currentStep is always replaced with new value
    # - Nested objects (intake, insurance, assessment) are deep merged
    #
    # State Transitions:
    # - Auto-transitions from "started" to "in_progress" on first update
    # - Extends session expiration by 1 hour on each update
    # - Cannot update sessions in terminal states (abandoned, expired, submitted)
    #
    # Caching:
    # - Writes progress to Redis cache with 1-hour TTL
    # - Uses namespace: "daybreak:sessions:progress:{session_id}"
    # - Cache is invalidated when session transitions to terminal state
    #
    class UpdateSessionProgress < BaseMutation
      description "Update session progress and extend expiration"

      argument :session_id, ID, required: true, description: "The session ID"
      argument :progress, GraphQL::Types::JSON, required: true, description: "Progress data to merge"

      field :session, Types::OnboardingSessionType, null: false

      def resolve(session_id:, progress:)
        # Load session
        session = OnboardingSession.find(session_id)

        # AC 2.4.6: Check if session has expired (past expiration time)
        if session.past_expiration?
          raise GraphQL::ExecutionError.new(
            'Session has expired',
            extensions: { code: Errors::ErrorCodes::SESSION_EXPIRED }
          )
        end

        # AC 2.5.6: Abandoned session cannot be resumed (mutation returns error if attempted)
        if session.abandoned?
          raise GraphQL::ExecutionError.new(
            'Session has been abandoned and cannot be updated',
            extensions: { code: Errors::ErrorCodes::SESSION_ABANDONED }
          )
        end

        # Validate session is active (not abandoned, expired, or submitted)
        raise GraphQL::ExecutionError, "Session is not active" unless session.active?

        # Validate progress structure
        validate_progress_structure!(progress)

        # Merge progress using service
        merger = ::Sessions::ProgressMerger.new(session, progress)
        merged_progress = merger.call

        # Update session
        session.transaction do
          # Auto-transition to in_progress on first update
          session.auto_transition_on_progress_update if session.started?

          # Update progress and extend expiration
          session.progress = merged_progress
          session.extend_expiration
          session.save!

          # Write to cache
          cache_session_progress(session)

          # Trigger subscription
          DaybreakHealthBackendSchema.subscriptions.trigger(
            'sessionUpdated',
            { session_id: session.id.to_s },
            session
          )
        end

        { session: session }
      rescue ActiveRecord::RecordNotFound
        raise GraphQL::ExecutionError, "Session not found"
      rescue ActiveRecord::RecordInvalid => e
        raise GraphQL::ExecutionError, e.message
      end

      private

      def validate_progress_structure!(progress)
        return if progress.blank?

        unless progress.is_a?(Hash)
          raise GraphQL::ExecutionError, "Progress must be a JSON object"
        end

        # Current step should be present
        if progress.key?('currentStep') && progress['currentStep'].blank?
          raise GraphQL::ExecutionError, "currentStep cannot be blank"
        end

        # Completed steps should be an array if present
        if progress.key?('completedSteps') && !progress['completedSteps'].is_a?(Array)
          raise GraphQL::ExecutionError, "completedSteps must be an array"
        end
      end

      def cache_session_progress(session)
        cache_key = "daybreak:sessions:progress:#{session.id}"
        Rails.cache.write(cache_key, session.progress, expires_in: 1.hour)
      end
    end
  end
end
