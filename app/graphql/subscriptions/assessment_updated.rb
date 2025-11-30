# frozen_string_literal: true

module Subscriptions
  # AssessmentUpdated subscription for real-time progress updates
  # Story 5.1: Conversational Screening Questions
  #
  # Triggered when assessment responses are submitted or status changes.
  #
  # Usage:
  #   subscription {
  #     assessmentUpdated(sessionId: "sess_123") {
  #       id
  #       status
  #       progressPercentage
  #       completedQuestionsCount
  #       phqAComplete
  #       gad7Complete
  #     }
  #   }
  #
  # Triggered by:
  #   DaybreakHealthBackendSchema.subscriptions.trigger(
  #     "assessmentUpdated",
  #     { session_id: "sess_123" },
  #     assessment_object
  #   )
  class AssessmentUpdated < GraphQL::Schema::Subscription
    description "Subscribe to assessment progress updates"

    # Argument
    argument :session_id, ID, required: true, description: "Session ID (with sess_ prefix)"

    # Return type
    field :id, ID, null: false, description: "Assessment ID"
    field :status, String, null: false, description: "Assessment status"
    field :progress_percentage, Integer, null: false, description: "Completion percentage"
    field :completed_questions_count, Integer, null: false, description: "Completed questions"
    field :total_questions_count, Integer, null: false, description: "Total questions"
    field :phq_a_complete, Boolean, null: false, description: "PHQ-A complete"
    field :gad_7_complete, Boolean, null: false, description: "GAD-7 complete"
    field :phq_a_score, Integer, null: true, description: "PHQ-A score (when complete)"
    field :gad_7_score, Integer, null: true, description: "GAD-7 score (when complete)"
    field :current_instrument, String, null: true, description: "Current instrument"
    field :next_question_id, String, null: true, description: "Next question ID"

    # Called when client subscribes
    def subscribe(session_id:)
      uuid = extract_uuid(session_id)
      session = OnboardingSession.find(uuid)
      authorize_session!(session)

      :no_response
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError, "Session not found"
    rescue GraphQL::ExecutionError => e
      raise e
    rescue StandardError => e
      Rails.logger.error("AssessmentUpdated subscription error: #{e.message}")
      raise GraphQL::ExecutionError, "Failed to subscribe to assessment updates"
    end

    # Called when subscription is triggered
    def update(session_id:)
      assessment = object

      {
        id: assessment.id,
        status: assessment.status,
        progress_percentage: assessment.progress_percentage,
        completed_questions_count: assessment.completed_questions_count,
        total_questions_count: assessment.total_questions_count,
        phq_a_complete: assessment.phq_a_complete?,
        gad_7_complete: assessment.gad_7_complete?,
        phq_a_score: assessment.phq_a_score,
        gad_7_score: assessment.gad_7_score,
        current_instrument: assessment.progress[:current_instrument],
        next_question_id: assessment.progress[:next_question_id]
      }
    end

    private

    def extract_uuid(session_id)
      clean_id = session_id.to_s.gsub(/^sess_/, "")
      if clean_id.length == 32 && !clean_id.include?("-")
        "#{clean_id[0..7]}-#{clean_id[8..11]}-#{clean_id[12..15]}-#{clean_id[16..19]}-#{clean_id[20..31]}"
      else
        clean_id
      end
    end

    def authorize_session!(session)
      current_session_id = context[:current_session_id]

      if current_session_id.blank?
        raise GraphQL::ExecutionError, "Authentication required"
      end

      unless session.id.to_s == current_session_id.to_s
        Rails.logger.warn("Unauthorized assessment subscription: requested #{session.id}, authenticated as #{current_session_id}")
        raise GraphQL::ExecutionError, "Unauthorized access to session"
      end
    end
  end
end
