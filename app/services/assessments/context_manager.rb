# frozen_string_literal: true

module Assessments
  # Context Manager for assessment phase
  # Story 5.1: Conversational Screening Questions
  #
  # Manages assessment state, question tracking, and progress.
  # Extends the conversation context manager for assessment-specific logic.
  #
  # State stored in Assessment.responses JSONB:
  # {
  #   phq_a: [{ item, question, value, rawText, timestamp }],
  #   gad_7: [...],
  #   progress: { phq_a_complete, gad_7_complete, current_instrument, next_question_id }
  # }
  class ContextManager
    attr_reader :session, :assessment, :child

    # Initialize context manager for a session
    #
    # @param session [OnboardingSession] The onboarding session
    def initialize(session:)
      @session = session
      @child = session.child
      @assessment = session.assessment || create_assessment
      @questions = load_questions
    end

    # Check if session is ready for assessment
    # FR26: Insurance phase must be complete
    #
    # @return [Boolean] True if ready for assessment
    def ready_for_assessment?
      # Check insurance verification is complete
      insurance = session.insurance
      return false unless insurance&.verification_status

      # Insurance must be verified, self-pay selected, or manual entry complete
      # manual_entry_complete is accepted for development/testing flows
      %w[verified self_pay manual_entry_complete].include?(insurance.verification_status)
    end

    # Get current phase of assessment
    #
    # @return [Symbol] :not_started, :phq_a, :gad_7, :complete
    def current_phase
      return :not_started if assessment.not_started?
      return :complete if assessment.complete?

      progress = assessment.progress
      case progress[:current_instrument]
      when 'phq_a' then :phq_a
      when 'gad_7' then :gad_7
      else :phq_a # Default to start
      end
    end

    # Get current question to ask
    #
    # @return [Hash, nil] Current question or nil if complete
    def current_question
      return nil if assessment.assessment_complete?

      question_id = assessment.progress[:next_question_id]
      return first_question if question_id.nil?

      find_question(question_id)
    end

    # Get next question after current
    #
    # @return [Hash, nil] Next question or nil if no more
    def next_question
      current = current_question
      return first_question if current.nil?

      QuestionSets.next_question(
        current_question_id: current[:id],
        age: child_age
      )
    end

    # Get first question (PHQ-A item 1)
    #
    # @return [Hash] First PHQ-A question
    def first_question
      @questions[:phq_a].first
    end

    # Start assessment
    # Transitions from not_started to in_progress
    #
    # @return [Boolean] True if started successfully
    def start_assessment
      return false unless ready_for_assessment?
      return true if assessment.in_progress?

      assessment.status = :in_progress
      update_progress_state('phq_a', 'phq_a_1')
      assessment.save!

      log_state_transition(:not_started, :in_progress)
      true
    end

    # Record a response to current question
    #
    # @param response_text [String] Natural language response
    # @param parsed_value [Integer] Likert value (0-3)
    # @return [Hash] Result with success flag and next question
    def record_response(response_text:, parsed_value:)
      question = current_question
      return { success: false, error: 'No current question' } unless question

      # Add response to assessment
      success = assessment.add_response(
        instrument: question[:id].split('_')[0..1].join('_'),
        item: question[:item],
        value: parsed_value,
        raw_text: response_text,
        question_text: question[:text]
      )

      return { success: false, errors: assessment.errors.full_messages } unless success

      # Check for phase transitions
      handle_phase_transitions

      # Save assessment
      assessment.save!

      {
        success: true,
        next_question: current_question,
        progress: {
          completed: assessment.completed_questions_count,
          total: assessment.total_questions_count,
          percentage: assessment.progress_percentage
        }
      }
    end

    # Build AI context for assessment
    # Returns messages array with system prompt and context
    #
    # @return [Array<Hash>] Messages for AI
    def build_ai_context
      messages = []

      # System prompt for assessment
      messages << {
        role: 'system',
        content: Ai::Prompts::AssessmentPrompt.system_prompt(
          child_name: child_name,
          child_age: child_age,
          parent_name: parent_name
        )
      }

      # Current question context
      question = current_question
      if question
        messages << {
          role: 'system',
          content: Ai::Prompts::AssessmentPrompt.question_context(
            question: question,
            progress: {
              completed_count: assessment.completed_questions_count
            },
            child_name: child_name
          )
        }
      end

      # Add recent conversation history
      messages.concat(conversation_history)

      messages
    end

    # Get progress summary for client
    #
    # @return [Hash] Progress information
    def progress_summary
      {
        status: assessment.status,
        current_phase: current_phase,
        current_question: current_question,
        completed_questions: assessment.completed_questions_count,
        total_questions: assessment.total_questions_count,
        percentage: assessment.progress_percentage,
        phq_a_complete: assessment.phq_a_complete?,
        gad_7_complete: assessment.gad_7_complete?
      }
    end

    # Check if at transition point (PHQ-A to GAD-7)
    #
    # @return [Boolean] True if just completed PHQ-A
    def at_phq_a_gad7_transition?
      assessment.phq_a_complete? && !assessment.gad_7_complete? &&
        assessment.gad_7_responses.empty?
    end

    # Check if assessment just completed
    #
    # @return [Boolean] True if all questions answered
    def just_completed?
      assessment.assessment_complete? && assessment.in_progress?
    end

    private

    # Create new assessment for session
    def create_assessment
      ::Assessment.create!(
        onboarding_session: session,
        responses: { phq_a: [], gad_7: [], progress: {}, scores: {} }.to_json,
        consent_given: true, # Assumed from intake consent
        status: :not_started
      )
    end

    # Load questions based on child's age
    def load_questions
      QuestionSets.all_questions(age: child_age)
    end

    # Get child's age
    def child_age
      @child&.age || 14 # Default to teen if unknown
    end

    # Get child's name
    def child_name
      @child&.first_name || 'your child'
    end

    # Get parent's name
    def parent_name
      session.parent&.first_name || 'there'
    end

    # Find question by ID
    def find_question(question_id)
      QuestionSets.find_question(question_id: question_id, age: child_age)
    end

    # Update progress state in assessment
    def update_progress_state(instrument, next_question_id)
      current = assessment.parsed_responses
      current[:progress] ||= {}
      current[:progress][:current_instrument] = instrument
      current[:progress][:next_question_id] = next_question_id
      assessment.responses = current.to_json
    end

    # Handle phase transitions after response
    def handle_phase_transitions
      # Check PHQ-A completion -> transition to GAD-7
      if assessment.phq_a_complete? && assessment.gad_7_responses.empty?
        update_progress_state('gad_7', 'gad_7_1')
      end

      # Check full completion
      if assessment.assessment_complete?
        assessment.status = :complete
        log_state_transition(:in_progress, :complete)
      end
    end

    # Get recent conversation history for context
    def conversation_history
      Message
        .where(onboarding_session_id: session.id)
        .order(created_at: :desc)
        .limit(10)
        .reverse
        .map { |msg| { role: msg.role.to_s, content: msg.content } }
    end

    # Log state transition for audit
    def log_state_transition(old_status, new_status)
      AuditLog.create!(
        onboarding_session_id: session.id,
        action: 'ASSESSMENT_STATUS_CHANGE',
        resource: 'Assessment',
        resource_id: assessment.id,
        details: {
          old_status: old_status.to_s,
          new_status: new_status.to_s,
          timestamp: Time.current.iso8601
        }
      )
    end
  end
end
