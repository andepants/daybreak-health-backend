# frozen_string_literal: true

module Ai
  # Context Manager for adaptive conversational flow (Story 3.2)
  # Manages conversation state, phase tracking, field collection, and adaptive question flow.
  #
  # Responsibilities:
  # - Track conversation phase (welcome, parent_info, child_info, concerns)
  # - Track collected fields to prevent question repetition
  # - Manage pending questions queue
  # - Analyze response completeness and relevance
  # - Generate adaptive follow-up questions
  # - Validate phase transitions
  #
  # State Schema (stored in session.progress):
  # {
  #   phase: "parent_info",
  #   collected_fields: ["first_name", "email"],
  #   pending_questions: ["What is your relationship to the child?"],
  #   field_metadata: {
  #     "first_name": { collected_at: "2025-11-29T...", confidence: "high" },
  #     "email": { collected_at: "2025-11-29T...", confidence: "high" }
  #   }
  # }
  #
  # Usage:
  #   context_manager = Ai::ContextManager.new(session_id: session.id)
  #   messages = context_manager.build_context
  #   context_manager.update_from_response(user_message, ai_response)
  class ContextManager
    # Maximum number of conversation messages to include in context
    MAX_MESSAGES = 50

    # Conversation phases in order
    PHASES = %w[welcome parent_info child_info concerns].freeze

    # Required fields for each phase to transition
    # AC 3.7.8: Track child info collection phase
    PHASE_REQUIRED_FIELDS = {
      'welcome' => [],
      'parent_info' => %w[parent_first_name parent_email],
      'child_info' => %w[child_first_name child_last_name child_date_of_birth],
      'concerns' => %w[primary_concern]
    }.freeze

    # Service age range for children (5-18 years)
    # AC 3.7.5: Age verification for service appropriate range
    MIN_AGE = 5
    MAX_AGE = 18

    # Initialize context manager for a specific session
    #
    # @param session_id [String] UUID of the onboarding session
    def initialize(session_id:)
      @session_id = session_id
      @session = OnboardingSession.find(session_id)
      initialize_state
    end

    # Build complete conversation context for AI
    # Includes system prompt, session progress, and last 50 messages
    # Story 3.5: Injects escalation context when session is escalated
    #
    # @return [Array<Hash>] Array of formatted messages with :role and :content
    def build_context
      messages = []

      # Add system prompt as first message
      messages << system_message

      # Add session progress summary if available
      if session_has_progress?
        messages << progress_message
      end

      # Add conversation history (last 50 messages)
      messages.concat(conversation_messages)

      # Story 3.5: Inject escalation context if in escalation mode
      messages = inject_escalation_context(messages)

      messages
    end

    # Get conversation history only (without system prompt or progress)
    # Useful for contexts where system message is handled separately
    #
    # @return [Array<Hash>] Array of conversation messages with :role and :content
    def conversation_messages
      Message
        .where(onboarding_session_id: @session_id)
        .order(created_at: :desc)
        .limit(MAX_MESSAGES)
        .reverse # Oldest first for chronological order
        .map { |msg| format_message(msg) }
    end

    # Get session progress summary
    # Returns current session status and any collected information
    #
    # @return [Hash] Progress summary with status, phase, and collected data
    def session_progress
      {
        status: @session.status,
        progress: @session.progress || {},
        current_phase: current_phase,
        collected_fields: collected_fields,
        pending_questions: pending_questions
      }
    end

    # Get current conversation phase
    #
    # @return [String] Current phase (welcome, parent_info, child_info, concerns)
    def current_phase
      @state['phase'] || 'welcome'
    end

    # Get collected fields list
    #
    # @return [Array<String>] List of collected field names
    def collected_fields
      @state['collected_fields'] || []
    end

    # Get pending questions queue
    #
    # @return [Array<String>] List of pending questions
    def pending_questions
      @state['pending_questions'] || []
    end

    # Mark a field as collected with metadata
    # AC: No question repetition - tracks collected fields
    #
    # @param field_name [String] Name of the field collected
    # @param confidence [String] Confidence level (high, medium, low)
    def mark_field_collected(field_name, confidence: 'high')
      @state['collected_fields'] ||= []
      @state['collected_fields'] << field_name unless @state['collected_fields'].include?(field_name)

      @state['field_metadata'] ||= {}
      @state['field_metadata'][field_name] = {
        'collected_at' => Time.current.iso8601,
        'confidence' => confidence
      }

      save_state
    end

    # Check if a field has been collected
    #
    # @param field_name [String] Name of the field to check
    # @return [Boolean] True if field has been collected
    def field_collected?(field_name)
      collected_fields.include?(field_name)
    end

    # Add question to pending queue
    #
    # @param question [String] Question to add
    def add_pending_question(question)
      @state['pending_questions'] ||= []
      @state['pending_questions'] << question unless @state['pending_questions'].include?(question)
      save_state
    end

    # Remove question from pending queue
    #
    # @param question [String] Question to remove
    def remove_pending_question(question)
      @state['pending_questions'] ||= []
      @state['pending_questions'].delete(question)
      save_state
    end

    # Analyze response for completeness and relevance
    # AC: AI analyzes response for completeness and relevance
    #
    # @param message_content [String] The user's message
    # @return [Hash] Analysis with completeness, ambiguity, and extracted fields
    def analyze_response(message_content)
      {
        is_complete: response_complete?(message_content),
        is_ambiguous: response_ambiguous?(message_content),
        extracted_fields: extract_fields_from_response(message_content),
        needs_clarification: needs_clarification?(message_content)
      }
    end

    # Generate adaptive follow-up questions based on context
    # AC: Follow-up questions adapt based on missing information, clarification, and related topics
    #
    # @return [Array<String>] List of suggested follow-up questions
    def generate_follow_ups
      questions = []

      # Check for missing required fields in current phase
      missing_fields = missing_required_fields
      missing_fields.each do |field|
        questions << generate_question_for_field(field) unless field_collected?(field)
      end

      # Add questions from pending queue
      questions.concat(pending_questions)

      # Limit to avoid overwhelming
      questions.take(3)
    end

    # Check if current phase can transition to next phase
    # AC: Conversation flows through phases, automatic progression based on completion
    #
    # @return [Boolean] True if phase transition is allowed
    def can_transition_phase?
      required_fields = PHASE_REQUIRED_FIELDS[current_phase] || []
      required_fields.all? { |field| field_collected?(field) }
    end

    # Transition to next phase
    # AC: Phase transitions update session progress automatically
    #
    # @return [String] New phase, or current phase if transition not allowed
    def transition_to_next_phase
      return current_phase unless can_transition_phase?

      current_index = PHASES.index(current_phase)
      return current_phase if current_index.nil? || current_index >= PHASES.length - 1

      new_phase = PHASES[current_index + 1]
      @state['phase'] = new_phase
      save_state

      new_phase
    end

    # Update context from user response and AI response
    # Extracts fields, updates phase, and manages questions
    #
    # @param user_message [String] User's message content
    # @param ai_response [String] AI's response content
    def update_from_response(user_message, ai_response)
      # Analyze user response
      analysis = analyze_response(user_message)

      # Extract and mark collected fields
      analysis[:extracted_fields].each do |field, value|
        mark_field_collected(field, confidence: value[:confidence])
      end

      # Check if phase transition should occur
      if can_transition_phase?
        transition_to_next_phase
      end

      # Update progress percentage
      update_progress_percentage
    end

    # Calculate progress percentage based on collected fields
    #
    # @return [Integer] Progress percentage (0-100)
    def calculate_progress_percentage
      total_fields = PHASE_REQUIRED_FIELDS.values.flatten.uniq.length
      return 0 if total_fields.zero?

      collected_count = collected_fields.length
      ((collected_count.to_f / total_fields) * 100).round
    end

    # Story 3.3: Help & Off-Topic Handling Methods

    # Get current conversation state
    # AC7: Conversation naturally returns to intake after addressing concerns
    #
    # @return [String] Current state (intake, help, off_topic)
    def conversation_state
      @state['conversation_state'] || 'intake'
    end

    # Set conversation to help mode
    # AC2: Clarifying questions answered with helpful context
    #
    # @param context [Hash] Help context (field, question, etc.)
    def enter_help_mode(context = {})
      @state['conversation_state'] = 'help'
      @state['help_context'] = {
        'field' => context[:field],
        'question' => context[:question],
        'entered_at' => Time.current.iso8601
      }
      save_state
    end

    # Set conversation to off-topic mode
    # AC3: Off-topic responses gently redirected to intake
    #
    # @param topic [String] Off-topic category
    def enter_off_topic_mode(topic)
      @state['conversation_state'] = 'off_topic'
      @state['off_topic_count'] = (@state['off_topic_count'] || 0) + 1
      @state['last_off_topic'] = {
        'topic' => topic,
        'timestamp' => Time.current.iso8601
      }
      save_state
    end

    # Return conversation to intake mode
    # AC7: Conversation naturally returns to intake after addressing concerns
    def return_to_intake_mode
      previous_state = @state['conversation_state']

      @state['conversation_state'] = 'intake'
      @state['help_context'] = nil

      save_state

      previous_state
    end

    # Check if currently in help mode
    #
    # @return [Boolean] True if in help mode
    def in_help_mode?
      conversation_state == 'help'
    end

    # Check if currently in off-topic mode
    #
    # @return [Boolean] True if off-topic mode
    def in_off_topic_mode?
      conversation_state == 'off_topic'
    end

    # Get help context
    #
    # @return [Hash, nil] Help context or nil
    def help_context
      @state['help_context']
    end

    # Get off-topic count
    # Useful for analytics and escalation
    #
    # @return [Integer] Number of off-topic redirections
    def off_topic_count
      @state['off_topic_count'] || 0
    end

    # Check if should escalate due to repeated confusion
    # If user is repeatedly asking for help or going off-topic,
    # might need human intervention
    #
    # @return [Boolean] True if should consider escalation
    def should_consider_escalation?
      off_topic_count >= 3
    end

    # Story 3.5: Human Escalation Request Methods

    # Enter escalation mode
    # AC 3.5.1: AI acknowledges empathetically without judgment
    # AC 3.5.5: Session continues with AI for data collection if parent agrees
    #
    # @param reason [String, nil] Optional reason for escalation
    def enter_escalation_mode(reason: nil)
      @state['conversation_state'] = 'escalation'
      @state['escalation_context'] = {
        'reason' => reason,
        'entered_at' => Time.current.iso8601
      }
      save_state
    end

    # Check if currently in escalation mode
    # AC 3.5.5: Session can continue with AI after escalation
    #
    # @return [Boolean] True if in escalation mode
    def in_escalation_mode?
      conversation_state == 'escalation' || @session.needs_human_contact
    end

    # Get escalation context
    #
    # @return [Hash, nil] Escalation context or nil
    def escalation_context
      @state['escalation_context']
    end

    # Build escalation response with contact options
    # AC 3.5.1: Empathetic acknowledgment
    # AC 3.5.4: Contact options provided
    # AC 3.5.5: Offer to continue data collection
    #
    # @return [String] Escalation response message
    def build_escalation_response
      contact_options = ContactOptions.for_parent
      reason = escalation_context&.dig('reason')

      Prompts::EscalationResponse.generate_response(
        contact_options: contact_options,
        escalation_reason: reason
      )
    end

    # Inject escalation mode into AI context
    # AC 3.5.1: Maintain empathetic tone during escalation
    # AC 3.5.5: Continue with gentler tone
    #
    # @param messages [Array<Hash>] Existing conversation context
    # @return [Array<Hash>] Context with escalation mode injected
    def inject_escalation_context(messages)
      return messages unless in_escalation_mode?

      # Add escalation mode system prompt after main system prompt
      escalation_prompt = {
        role: 'system',
        content: Prompts::EscalationResponse.escalation_mode_prompt
      }

      # Insert after first system message
      messages.insert(1, escalation_prompt)
      messages
    end

    # Story 3.7: Child Information Collection Methods

    # Validate child's age is within service range
    # AC 3.7.5: Age verified (service appropriate range 5-18)
    #
    # @param date_of_birth [String] Date of birth in ISO format or parseable format
    # @return [Hash] Validation result with valid flag, age, and message
    def validate_child_age(date_of_birth)
      return { valid: false, message: 'Date of birth is required' } if date_of_birth.blank?

      begin
        dob = Date.parse(date_of_birth)

        # AC 3.7.10: DOB validation - not in future
        if dob > Date.today
          return {
            valid: false,
            message: 'Date of birth cannot be in the future'
          }
        end

        # Calculate age
        today = Date.today
        age = today.year - dob.year
        # Subtract 1 if birthday hasn't occurred yet this year
        age -= 1 if today.month < dob.month || (today.month == dob.month && today.day < dob.day)

        # AC 3.7.5: Age within service range (5-18)
        if age < MIN_AGE
          return {
            valid: false,
            age: age,
            message: "Daybreak Health serves children ages #{MIN_AGE}-#{MAX_AGE}. Your child (age #{age}) is below our minimum age range."
          }
        elsif age > MAX_AGE
          return {
            valid: false,
            age: age,
            message: "Daybreak Health serves children and teens up to age #{MAX_AGE}. Your child (age #{age}) would be better served by adult mental health services."
          }
        end

        {
          valid: true,
          age: age,
          message: "Age #{age} is within service range"
        }
      rescue ArgumentError, TypeError
        {
          valid: false,
          message: 'Invalid date format. Please provide date of birth in a standard format (e.g., YYYY-MM-DD)'
        }
      end
    end

    # Handle multiple children scenario
    # AC 3.7.7: Multiple children scenario handled (one session per child)
    #
    # @return [String] Message to inform parent about multiple children process
    def multiple_children_message
      <<~MESSAGE.strip
        I understand you have concerns about more than one child. To ensure each child
        receives focused, personalized care, we complete a separate intake session for
        each child.

        For today's session, let's focus on one child. After we complete this intake,
        we can start a new session for another child, or you can schedule it for a
        time that works better for you.
      MESSAGE
    end

    # Check if child info phase is complete
    # AC 3.7.8: Child's age calculated and stored
    # AC 3.7.9: Data stored in Child entity linked to session
    #
    # @return [Boolean] True if child info phase has all required data
    def child_info_complete?
      return false unless current_phase == 'child_info'

      required_fields = PHASE_REQUIRED_FIELDS['child_info']
      required_fields.all? { |field| field_collected?(field) }
    end

    # Get child info phase-specific guidance
    # AC 3.7.3, 3.7.4, 3.7.6: Primary concerns, medical history, sensitive topics
    #
    # @return [String] Additional prompt guidance for child info phase
    def child_info_phase_guidance
      return '' unless current_phase == 'child_info'

      Prompts::ChildInfoPrompt.phase_guidance
    end

    # Extract child data from conversational response
    # AC 3.7.8: Extract structured data from conversational responses
    #
    # @param response [String] User's response containing child information
    # @return [Hash] Extracted child data
    def extract_child_data(response)
      # This is a simplified version - in production, would use AI-powered extraction
      # or structured output from the AI model
      extracted = {}

      # Extract age/date of birth patterns
      if response.match?(/\b(\d{1,2})\s*years?\s*old\b/i)
        age = response.match(/\b(\d{1,2})\s*years?\s*old\b/i)[1].to_i
        extracted['child_age'] = { value: age, confidence: 'medium' }
      end

      # Extract date patterns (MM/DD/YYYY, YYYY-MM-DD, etc.)
      date_patterns = [
        /\b(\d{4})-(\d{2})-(\d{2})\b/,  # YYYY-MM-DD
        /\b(\d{1,2})\/(\d{1,2})\/(\d{4})\b/,  # MM/DD/YYYY
        /\b(\d{1,2})-(\d{1,2})-(\d{4})\b/  # MM-DD-YYYY
      ]

      date_patterns.each do |pattern|
        if response.match?(pattern)
          extracted['child_date_of_birth'] = { confidence: 'high' }
          break
        end
      end

      # Extract grade level
      if response.match?(/\b(\d{1,2})(st|nd|rd|th)?\s*grade\b/i)
        extracted['child_grade'] = { confidence: 'high' }
      end

      extracted
    end

    private

    # Initialize state from session progress or create new state
    def initialize_state
      @state = @session.progress&.dig('context_manager') || {
        'phase' => 'welcome',
        'collected_fields' => [],
        'pending_questions' => [],
        'field_metadata' => {},
        # Story 3.3: Help & Off-Topic Handling
        'conversation_state' => 'intake', # intake, help, off_topic
        'help_context' => nil, # Stores context when in help mode
        'off_topic_count' => 0 # Track off-topic redirections
      }
    end

    # Save state back to session progress
    def save_state
      progress = @session.progress || {}
      progress['context_manager'] = @state
      @session.update!(progress: progress)
    end

    # Update progress percentage in session
    def update_progress_percentage
      progress = @session.progress || {}
      progress['percentage'] = calculate_progress_percentage
      @session.update!(progress: progress)
    end

    # Check if response is complete
    #
    # @param message_content [String] Message to check
    # @return [Boolean] True if response appears complete
    def response_complete?(message_content)
      # Simple heuristic: check if message has sufficient length and ends properly
      return false if message_content.blank?
      return false if message_content.length < 3

      # Check for incomplete indicators
      incomplete_indicators = ['...', 'uh', 'um', 'hmm']
      return false if incomplete_indicators.any? { |indicator| message_content.downcase.end_with?(indicator) }

      true
    end

    # Check if response is ambiguous
    #
    # @param message_content [String] Message to check
    # @return [Boolean] True if response appears ambiguous
    def response_ambiguous?(message_content)
      return true if message_content.blank?

      # Check for ambiguous phrases
      ambiguous_phrases = [
        'not sure', 'maybe', 'i think', 'probably', 'kind of', 'sort of',
        "don't know", 'unclear', 'confused'
      ]

      ambiguous_phrases.any? { |phrase| message_content.downcase.include?(phrase) }
    end

    # Check if response needs clarification
    #
    # @param message_content [String] Message to check
    # @return [Boolean] True if clarification needed
    def needs_clarification?(message_content)
      response_ambiguous?(message_content) || !response_complete?(message_content)
    end

    # Extract fields from response using pattern matching
    # This is a simplified version - in production, would use structured output from AI
    #
    # @param message_content [String] Message to extract from
    # @return [Hash] Extracted fields with confidence scores
    def extract_fields_from_response(message_content)
      extracted = {}

      # Email pattern
      if message_content.match?(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/)
        extracted['parent_email'] = { confidence: 'high' }
      end

      # Phone pattern (simple US format)
      if message_content.match?(/\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/)
        extracted['parent_phone'] = { confidence: 'high' }
      end

      # Name pattern (after common prompts)
      if message_content.match?(/(?:my name is|i'm|i am|call me)\s+([A-Z][a-z]+)/i)
        extracted['parent_first_name'] = { confidence: 'medium' }
      end

      extracted
    end

    # Get missing required fields for current phase
    #
    # @return [Array<String>] List of missing field names
    def missing_required_fields
      required_fields = PHASE_REQUIRED_FIELDS[current_phase] || []
      required_fields.reject { |field| field_collected?(field) }
    end

    # Generate question for a specific field
    #
    # @param field_name [String] Field to generate question for
    # @return [String] Generated question
    def generate_question_for_field(field_name)
      case field_name
      when 'parent_first_name'
        "What's your first name?"
      when 'parent_email'
        "What's the best email address to reach you?"
      when 'parent_phone'
        "What's a good phone number to contact you?"
      when 'child_first_name'
        "What's your child's first name?"
      when 'child_last_name'
        "And what's your child's last name?"
      when 'child_date_of_birth'
        "When was your child born? You can share their date of birth in any format that's comfortable."
      when 'child_age'
        "How old is your child?"
      when 'child_gender'
        "What pronouns does your child use, or how do they identify?"
      when 'child_school_name'
        "What school does your child attend?"
      when 'child_grade'
        "What grade is your child in?"
      when 'primary_concern'
        "What brings you to Daybreak Health today?"
      else
        "Can you tell me about #{field_name.humanize.downcase}?"
      end
    end

    # Format system message with intake prompt
    #
    # @return [Hash] System message with role and content
    def system_message
      {
        role: "system",
        content: Prompts::IntakePrompt.system_prompt
      }
    end

    # Format progress summary as a system message
    # Helps AI understand what information has been collected
    # AC: Progress updates reflect completed topics
    #
    # @return [Hash] Progress message with role and content
    def progress_message
      summary = "Session Progress Summary:\n"
      summary += "- Status: #{@session.status}\n"
      summary += "- Current Phase: #{current_phase}\n"
      summary += "- Progress: #{calculate_progress_percentage}%\n"

      # List collected fields (PHI-safe - only field names, not values)
      if collected_fields.any?
        summary += "- Collected Information: #{collected_fields.join(', ')}\n"
      end

      # List missing required fields for current phase
      missing = missing_required_fields
      if missing.any?
        summary += "- Still Needed: #{missing.map(&:humanize).join(', ')}\n"
      end

      # List pending questions
      if pending_questions.any?
        summary += "- Pending Questions: #{pending_questions.length}\n"
      end

      {
        role: "system",
        content: summary
      }
    end

    # Check if session has any progress data
    #
    # @return [Boolean] True if session has progress data
    def session_has_progress?
      collected_fields.any? || pending_questions.any?
    end

    # Format a message model for AI provider
    # Converts database record to provider-compatible hash
    #
    # @param message [Message] Message model instance
    # @return [Hash] Formatted message with :role and :content
    def format_message(message)
      {
        role: message.role.to_s,
        content: message.content
      }
    end
  end
end
