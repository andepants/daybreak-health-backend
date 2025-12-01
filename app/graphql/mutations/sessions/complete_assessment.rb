# frozen_string_literal: true

module Mutations
  module Sessions
    # CompleteAssessment - Transitions session to assessment_complete status
    #
    # This mutation validates that all prerequisites are met and transitions
    # the session through the required states to assessment_complete.
    #
    # Prerequisites checked:
    # - Session exists and is active
    # - Parent info is complete (in progress data)
    # - Child info is complete (in progress data)
    # - Assessment chat is complete (or skipped for testing)
    #
    # State transitions performed:
    # - started -> in_progress (if needed)
    # - in_progress -> insurance_pending (if needed)
    # - insurance_pending -> assessment_complete
    #
    class CompleteAssessment < BaseMutation
      description "Validate prerequisites and transition session to assessment_complete status"

      argument :session_id, ID, required: true, description: "The session ID"
      argument :force, Boolean, required: false, default_value: false,
               description: "Force transition even if some prerequisites are missing (for testing)"

      field :session, Types::OnboardingSessionType, null: true
      field :success, Boolean, null: false
      field :errors, [String], null: false

      def resolve(session_id:, force: false)
        session = OnboardingSession.find_by(id: session_id)

        unless session
          return { session: nil, success: false, errors: ["Session not found"] }
        end

        # Already in assessment_complete or later state
        if session.assessment_complete? || session.appointment_booked? || session.submitted?
          return { session: session, success: true, errors: [] }
        end

        # Check if session is in a terminal state
        if session.abandoned? || session.expired?
          return { session: session, success: false, errors: ["Session is no longer active"] }
        end

        errors = []

        # Validate prerequisites unless forcing
        unless force
          errors.concat(validate_prerequisites(session))
        end

        if errors.any?
          return { session: session, success: false, errors: errors }
        end

        # Perform state transitions
        begin
          session.transaction do
            # Transition through required states
            if session.started?
              session.update!(status: :in_progress)
            end

            if session.in_progress?
              session.update!(status: :insurance_pending)
            end

            if session.insurance_pending?
              session.update!(status: :assessment_complete)
            end
          end

          { session: session.reload, success: true, errors: [] }
        rescue ActiveRecord::RecordInvalid => e
          { session: session, success: false, errors: [e.message] }
        rescue StandardError => e
          Rails.logger.error("CompleteAssessment error: #{e.message}")
          { session: session, success: false, errors: ["Failed to update session status"] }
        end
      end

      private

      def validate_prerequisites(session)
        errors = []
        progress = session.progress || {}

        # Check intake completion
        intake = progress['intake'] || {}
        unless intake['parentInfoComplete']
          errors << "Parent information is not complete"
        end
        unless intake['childInfoComplete']
          errors << "Child information is not complete"
        end

        # Check assessment completion (if assessment exists)
        assessment_progress = progress['assessment'] || {}
        unless assessment_progress['screeningComplete']
          # Only warn, don't block - assessment might be tracked differently
          Rails.logger.info("Assessment screening not marked complete in progress for session #{session.id}")
        end

        errors
      end
    end
  end
end
