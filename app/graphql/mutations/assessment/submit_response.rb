# frozen_string_literal: true

module Mutations
  module Assessment
    # SubmitAssessmentResponse mutation for recording screening responses
    # Story 5.1: Conversational Screening Questions
    #
    # FR26 Validation:
    # - Insurance phase must be complete
    # - Response value must be valid Likert (0-3)
    # - Response text must be 1-500 characters
    # - Question ID must be valid for current instrument
    # - No duplicate responses for same question
    #
    # Usage:
    #   mutation {
    #     submitAssessmentResponse(
    #       sessionId: "sess_123",
    #       questionId: "phq_a_1",
    #       responseText: "several days"
    #     ) {
    #       assessment { id status progressPercentage }
    #       nextQuestion { id text }
    #       errors
    #     }
    #   }
    class SubmitResponse < GraphQL::Schema::Mutation
      description "Submit a response to a screening assessment question"

      # Arguments
      argument :session_id, ID, required: true, description: "Session ID (with sess_ prefix)"
      argument :question_id, String, required: true, description: "Question ID (e.g., phq_a_1)"
      argument :response_text, String, required: true, description: "Natural language response"
      argument :response_value, Integer, required: false, description: "Optional explicit Likert value (0-3)"

      # Return fields
      field :assessment, Types::AssessmentType, null: true, description: "Updated assessment"
      field :next_question, Types::AssessmentQuestionType, null: true, description: "Next question to ask"
      field :progress, Types::AssessmentProgressType, null: true, description: "Assessment progress"
      field :errors, [String], null: false, description: "Validation errors"

      def resolve(session_id:, question_id:, response_text:, response_value: nil)
        # Extract UUID from session_id
        uuid = extract_uuid(session_id)

        # Find session and verify access
        session = OnboardingSession.find(uuid)
        authorize_session!(session)

        # Validate session status
        validate_session_status!(session)

        # Initialize assessment context manager
        context_manager = ::Assessments::ContextManager.new(session: session)

        # FR26: Verify insurance phase is complete
        unless context_manager.ready_for_assessment?
          return error_result("Insurance verification must be complete before assessment")
        end

        # Start assessment if not started
        unless context_manager.assessment.in_progress?
          context_manager.start_assessment
        end

        # Validate question ID
        child_age = session.child&.age || 14
        unless ::Assessments::QuestionSets.valid_question_id?(question_id: question_id, age: child_age)
          return error_result("Invalid question ID: #{question_id}")
        end

        # FR26: Validate response text length
        validation = ::Assessments::ResponseParser.validate(response_text)
        unless validation[:valid]
          return error_result(validation[:errors].join(', '))
        end

        # Parse response to Likert value if not provided
        if response_value.nil?
          parse_result = ::Assessments::ResponseParser.parse(response_text)

          if parse_result[:needs_clarification]
            # Return with clarification prompt
            return {
              assessment: context_manager.assessment,
              next_question: nil,
              progress: build_progress(context_manager),
              errors: ["Response unclear. #{parse_result[:suggestion]}"]
            }
          end

          response_value = parse_result[:value]
        end

        # FR26: Validate Likert value range
        unless response_value.is_a?(Integer) && response_value.between?(0, 3)
          return error_result("Response value must be between 0 and 3")
        end

        # Record the response
        result = context_manager.record_response(
          response_text: response_text,
          parsed_value: response_value
        )

        unless result[:success]
          return error_result(result[:errors]&.join(', ') || result[:error])
        end

        # Trigger subscription for progress update
        trigger_assessment_subscription(session, context_manager.assessment)

        # Create audit log
        log_response_submission(session, context_manager.assessment, question_id)

        # Build next question
        next_question = result[:next_question]

        {
          assessment: context_manager.assessment,
          next_question: next_question ? build_question_type(next_question) : nil,
          progress: build_progress(context_manager),
          errors: []
        }
      rescue ActiveRecord::RecordNotFound
        error_result("Session not found")
      rescue GraphQL::ExecutionError => e
        error_result(e.message)
      rescue StandardError => e
        Rails.logger.error("SubmitAssessmentResponse error: #{e.class.name} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
        error_result("An error occurred. Please try again.")
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
        current_session = context[:current_session]
        current_session_id = current_session&.id || context[:current_session_id]

        if current_session_id.blank?
          raise GraphQL::ExecutionError, "Authentication required"
        end

        unless session.id == current_session_id
          raise GraphQL::ExecutionError, "Unauthorized access to session"
        end
      end

      def validate_session_status!(session)
        raise GraphQL::ExecutionError, "Session has expired" if session.expired?
        raise GraphQL::ExecutionError, "Session is already submitted" if session.submitted?
        raise GraphQL::ExecutionError, "Session has been abandoned" if session.abandoned?
      end

      def error_result(message)
        {
          assessment: nil,
          next_question: nil,
          progress: nil,
          errors: [message]
        }
      end

      def build_progress(context_manager)
        summary = context_manager.progress_summary
        {
          status: summary[:status],
          completed_questions: summary[:completed_questions],
          total_questions: summary[:total_questions],
          percentage: summary[:percentage],
          phq_a_complete: summary[:phq_a_complete],
          gad_7_complete: summary[:gad_7_complete],
          current_phase: summary[:current_phase].to_s
        }
      end

      def build_question_type(question)
        {
          id: question[:id],
          item: question[:item],
          text: question[:text],
          domain: question[:domain],
          instrument: question[:id].start_with?('phq') ? 'PHQ-A' : 'GAD-7'
        }
      end

      def trigger_assessment_subscription(session, assessment)
        DaybreakHealthBackendSchema.subscriptions.trigger(
          "assessmentUpdated",
          { session_id: "sess_#{session.id.gsub('-', '')}" },
          assessment
        )
      rescue StandardError => e
        Rails.logger.warn("Assessment subscription trigger failed: #{e.message}")
      end

      def log_response_submission(session, assessment, question_id)
        AuditLog.create!(
          onboarding_session_id: session.id,
          action: 'ASSESSMENT_RESPONSE_SUBMITTED',
          resource: 'Assessment',
          resource_id: assessment.id,
          details: {
            question_id: question_id,
            completed_questions: assessment.completed_questions_count,
            timestamp: Time.current.iso8601
            # Note: Never log response content (PHI)
          }
        )
      end
    end
  end
end
