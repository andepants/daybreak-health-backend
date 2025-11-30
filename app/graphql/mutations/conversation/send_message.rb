# frozen_string_literal: true

module Mutations
  module Conversation
    # SendMessage mutation for conversational AI intake
    #
    # Acceptance Criteria:
    # - AC1: Accepts message content and stores with role USER
    # - AC2: Calls AI service with conversation context
    # - AC4: Maintains conversation context across messages
    #
    # Flow:
    # 1. Store user message with timestamp
    # 2. Build conversation context
    # 3. Call AI client
    # 4. Store assistant response
    # 5. Trigger GraphQL subscription
    # 6. Return both messages
    #
    # Usage:
    #   mutation {
    #     sendMessage(sessionId: "sess_123", content: "I need help with my child") {
    #       userMessage { id role content createdAt }
    #       assistantMessage { id role content createdAt }
    #     }
    #   }
    class SendMessage < GraphQL::Schema::Mutation
      description "Send a message in the conversational intake"

      # Arguments
      argument :session_id, ID, required: true, description: "Session ID (with sess_ prefix)"
      argument :content, String, required: true, description: "Message content from user"

      # Return fields
      field :user_message, Types::MessageType, null: true, description: "The user's message"
      field :assistant_message, Types::MessageType, null: true, description: "The AI assistant's response"
      field :errors, [String], null: false, description: "Errors if mutation failed"

      def resolve(session_id:, content:)
        # Extract UUID from session_id (remove sess_ prefix)
        uuid = extract_uuid(session_id)

        # Find session and verify access
        session = OnboardingSession.find(uuid)
        authorize_session!(session)

        # Validate session is not expired or completed
        validate_session_status!(session)

        # Store user message (AC1)
        user_message = store_user_message(session, content)

        # Story 5.1: Check if session is in assessment phase
        if in_assessment_phase?(session)
          return handle_assessment_message(session, user_message, content)
        end

        # Story 3.3: Classify intent before AI call
        context_manager = Ai::ContextManager.new(session_id: session.id)
        intent_result = classify_message_intent(content, context_manager)

        # Store intent in message metadata (Story 3.3)
        user_message.store_intent(intent_result)
        user_message.save!

        # Story 3.5: Check for escalation intent before AI call
        # AC 3.5.8: AI detects escalation intent from specific phrases
        escalation_detector = Ai::EscalationDetector.new
        escalation_result = escalation_detector.detect_escalation_intent(content)

        # Track if escalation was just detected (for response generation)
        escalation_just_detected = false

        # If escalation detected, trigger human contact request
        if escalation_result[:escalation_detected] && !session.needs_human_contact
          handle_escalation_request(session, escalation_result, context_manager)
          escalation_just_detected = true
        end

        # Build conversation context with adaptive flow (AC4, Story 3.2)
        messages = context_manager.build_context

        # Story 3.3: Handle help and off-topic intents
        handle_intent(intent_result, context_manager, user_message)

        # Story 3.5: If escalation was just detected, generate empathetic response
        # AC 3.5.1: AI acknowledges empathetically without judgment
        # AC 3.5.4: Contact options provided
        if escalation_just_detected
          # Use escalation response template instead of AI call
          ai_response = {
            content: context_manager.build_escalation_response
          }
        else
          # Call AI service (AC2) with help/off-topic context
          ai_response = call_ai_service(messages, context_manager, intent_result)
        end

        # Store assistant response (AC2)
        assistant_message = store_assistant_message(session, ai_response[:content])

        # Update context manager from responses (Story 3.2)
        # Extracts fields, updates phase, manages adaptive flow
        context_manager.update_from_response(content, ai_response[:content])

        # Extend session expiration on activity
        session.extend_expiration
        session.save!

        # Trigger GraphQL subscription (handled in MessageReceived subscription)
        trigger_subscription(session, assistant_message)

        # Create audit logs (Task 8)
        log_message_activity(session, user_message, assistant_message)

        {
          user_message: user_message,
          assistant_message: assistant_message,
          errors: []
        }
      rescue ActiveRecord::RecordNotFound
        {
          user_message: nil,
          assistant_message: nil,
          errors: ["Session not found"]
        }
      rescue GraphQL::ExecutionError => e
        {
          user_message: nil,
          assistant_message: nil,
          errors: [e.message]
        }
      rescue StandardError => e
        # Log error class and sanitized info only - NEVER message content (PHI)
        Rails.logger.error("SendMessage mutation error: #{e.class.name}")
        Rails.logger.error("Session ID: #{session&.id}") # ID is OK, content is not
        # Only log backtrace in development
        Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?

        {
          user_message: nil,
          assistant_message: nil,
          errors: ["An error occurred while processing your message. Please try again."]
        }
      end

      private

      # Extract UUID from session_id (remove sess_ prefix)
      #
      # @param session_id [String] Session ID with sess_ prefix
      # @return [String] UUID
      def extract_uuid(session_id)
        # Remove sess_ prefix and reformat as UUID
        clean_id = session_id.to_s.gsub(/^sess_/, "")

        # Add dashes back to UUID format if needed
        if clean_id.length == 32 && !clean_id.include?("-")
          # Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
          "#{clean_id[0..7]}-#{clean_id[8..11]}-#{clean_id[12..15]}-#{clean_id[16..19]}-#{clean_id[20..31]}"
        else
          clean_id
        end
      end

      # Authorize session access
      # Ensures user can only send messages to their own session
      #
      # @param session [OnboardingSession] Session to authorize
      # @raise [GraphQL::ExecutionError] If unauthorized
      def authorize_session!(session)
        # Verify JWT token is present and valid
        # Check both context[:current_session] (from GraphqlController) and context[:current_session_id]
        current_session = context[:current_session]
        current_session_id = current_session&.id || context[:current_session_id]

        if current_session_id.blank?
          raise GraphQL::ExecutionError, "Authentication required"
        end

        # Verify session belongs to current user (session ID must match)
        # Architecture says sessions should have user_id or similar
        # For anonymous sessions, we verify the JWT session_id matches
        unless session.id == current_session_id
          raise GraphQL::ExecutionError, "Unauthorized access to session"
        end
      end

      # Validate session status allows new messages
      #
      # @param session [OnboardingSession] Session to validate
      # @raise [GraphQL::ExecutionError] If session is invalid
      def validate_session_status!(session)
        if session.expired?
          raise GraphQL::ExecutionError, "Session has expired"
        end

        if session.submitted?
          raise GraphQL::ExecutionError, "Session is already submitted"
        end

        if session.abandoned?
          raise GraphQL::ExecutionError, "Session has been abandoned"
        end
      end

      # Store user message in database
      # AC1: Stores message with role USER and timestamp
      #
      # @param session [OnboardingSession] The session
      # @param content [String] Message content
      # @return [Message] Created message
      def store_user_message(session, content)
        Message.create!(
          onboarding_session: session,
          role: :user,
          content: content
        )
      end

      # Story 3.3: Classify message intent
      # Determines if message is answer, question, help request, off-topic, or clarification
      #
      # @param content [String] Message content
      # @param context_manager [Ai::ContextManager] Context manager
      # @return [Hash] Intent classification result
      def classify_message_intent(content, context_manager)
        # Build context for intent classifier
        classifier_context = {
          current_phase: context_manager.current_phase,
          collected_fields: context_manager.collected_fields,
          missing_fields: context_manager.send(:missing_required_fields),
          conversation_state: context_manager.conversation_state
        }

        Ai::IntentClassifier.call(message: content, context: classifier_context)
      end

      # Story 3.3: Handle intent-specific actions
      # Updates context manager state based on classified intent
      #
      # @param intent_result [Hash] Intent classification result
      # @param context_manager [Ai::ContextManager] Context manager
      # @param message [Message] User message
      def handle_intent(intent_result, context_manager, message)
        case intent_result[:intent]
        when :help_request, :clarification
          # Enter help mode with context
          context_manager.enter_help_mode(
            field: extract_field_from_message(message.content),
            question: message.content
          )

          # Log help interaction for analytics
          log_help_interaction(message, intent_result)

        when :off_topic
          # Enter off-topic mode
          topic = categorize_off_topic(message.content)
          context_manager.enter_off_topic_mode(topic)

        when :answer
          # If we were in help or off-topic mode, return to intake
          if context_manager.in_help_mode? || context_manager.in_off_topic_mode?
            context_manager.return_to_intake_mode
          end
        end
      end

      # Extract field name from message content
      #
      # @param message_content [String] User message content
      # @return [String, nil] Field name if detected
      def extract_field_from_message(message_content)
        # Simple extraction - in production, could use NLP
        field_keywords = {
          'email' => 'email',
          'phone' => 'phone',
          'name' => 'name',
          'age' => 'child_age',
          'birth' => 'date_of_birth',
          'concern' => 'concerns'
        }

        field_keywords.each do |keyword, field|
          return field if message_content.to_s.downcase.include?(keyword)
        end

        nil
      end

      # Categorize off-topic message into topic
      #
      # @param message_content [String] User message content
      # @return [String] Topic category
      def categorize_off_topic(message_content)
        return 'general' if message_content.blank?

        case message_content.to_s.downcase
        when /cost|price|pay|afford/
          'cost_concern'
        when /hour|time|when|schedule/
          'timeline_concern'
        when /where|location|address/
          'location_concern'
        else
          'general_question'
        end
      end

      # Log help interaction for analytics
      #
      # @param message [Message] Message that triggered help
      # @param intent_result [Hash] Intent classification result
      def log_help_interaction(message, intent_result)
        Ai::HelpAnalytics.new.log_help_interaction(message, intent_result)
      end

      # Call AI service with conversation context
      # AC2: AI service called with conversation context
      # Story 3.2: Pass context manager state for adaptive flow
      # Story 3.3: Include help/off-topic context
      #
      # @param messages [Array<Hash>] Conversation context
      # @param context_manager [Ai::ContextManager] Context manager for adaptive flow
      # @param intent_result [Hash] Intent classification result
      # @return [Hash] AI response with :content
      def call_ai_service(messages, context_manager = nil, intent_result = nil)
        client = Ai::Client.new

        # Build context with adaptive flow information
        ai_context = {}
        if context_manager
          ai_context[:current_phase] = context_manager.current_phase
          ai_context[:collected_fields] = context_manager.collected_fields
          ai_context[:progress_percentage] = context_manager.calculate_progress_percentage

          # Story 3.3: Add help/off-topic context
          ai_context[:conversation_state] = context_manager.conversation_state
          ai_context[:help_context] = context_manager.help_context if context_manager.in_help_mode?
        end

        # Story 3.3: Add intent information
        if intent_result
          ai_context[:user_intent] = intent_result[:intent]
          ai_context[:intent_confidence] = intent_result[:confidence]
        end

        client.chat(messages: messages, context: ai_context)
      rescue Ai::Providers::BaseProvider::RateLimitError => e
        # Rate limit - return graceful error message
        Rails.logger.warn("AI rate limit hit: #{e.message}")
        {
          content: "I apologize, but I'm experiencing high volume right now. " \
                   "Please wait a moment and try again."
        }
      rescue Ai::Providers::BaseProvider::ApiError => e
        # API error - return graceful error message
        Rails.logger.error("AI API error: #{e.message}")
        {
          content: "I apologize, but I'm having trouble processing your message right now. " \
                   "Please try again in a moment."
        }
      end

      # Store assistant response in database
      # AC2: Response stored with role ASSISTANT
      #
      # @param session [OnboardingSession] The session
      # @param content [String] Assistant response content
      # @return [Message] Created message
      def store_assistant_message(session, content)
        Message.create!(
          onboarding_session: session,
          role: :assistant,
          content: content
        )
      end

      # Trigger GraphQL subscription for real-time message delivery
      # AC3: Response streamed via GraphQL subscription
      #
      # @param session [OnboardingSession] The session
      # @param message [Message] The assistant message
      def trigger_subscription(session, message)
        # Trigger the MessageReceived subscription
        DaybreakHealthBackendSchema.subscriptions.trigger(
          "messageReceived",
          { session_id: "sess_#{session.id.gsub('-', '')}" },
          message
        )
      end

      # Log message activity for audit trail
      # AC8: Audit logging for MESSAGE_SENT and AI_RESPONSE
      #
      # @param session [OnboardingSession] The session
      # @param user_message [Message] User message
      # @param assistant_message [Message] Assistant message
      def log_message_activity(session, user_message, assistant_message)
        # Log user message sent
        AuditLog.create!(
          onboarding_session_id: session.id,
          action: "MESSAGE_SENT",
          resource: "Message",
          resource_id: user_message.id,
          details: {
            message_id: user_message.id,
            role: "user",
            timestamp: user_message.created_at.iso8601
            # NOTE: Never log actual content (PHI)
          }
        )

        # Log AI response
        AuditLog.create!(
          onboarding_session_id: session.id,
          action: "AI_RESPONSE",
          resource: "Message",
          resource_id: assistant_message.id,
          details: {
            message_id: assistant_message.id,
            role: "assistant",
            timestamp: assistant_message.created_at.iso8601
            # NOTE: Never log actual content (PHI)
          }
        )
      end

      # Story 3.5: Handle escalation request
      # AC 3.5.2: Session flagged for human follow-up
      # AC 3.5.3: needs_human_contact flag set to true
      # AC 3.5.6: Care team notified
      # AC 3.5.8: AI detects escalation intent from phrases
      #
      # @param session [OnboardingSession] The session
      # @param escalation_result [Hash] Result from escalation detector
      # @param context_manager [Ai::ContextManager] Context manager instance
      def handle_escalation_request(session, escalation_result, context_manager)
        # Set escalation flags on session
        session.needs_human_contact = true
        session.escalation_requested_at = Time.current
        # Don't set escalation_reason here - it's for explicit user-provided reasons
        session.save!

        # Enter escalation mode in context manager
        context_manager.enter_escalation_mode

        # Trigger care team notification asynchronously
        EscalationNotificationJob.perform_later(session.id)

        # Create audit log for automatic escalation detection
        AuditLog.create!(
          onboarding_session_id: session.id,
          action: 'ESCALATION_DETECTED',
          resource: 'OnboardingSession',
          resource_id: session.id,
          details: {
            matched_phrases: escalation_result[:matched_phrases],
            detection_method: 'automatic',
            timestamp: Time.current.iso8601
          },
          ip_address: context[:ip_address],
          user_agent: context[:user_agent]
        )

        Rails.logger.info("Escalation detected for session #{session.id} - " \
                          "matched phrases: #{escalation_result[:matched_phrases].join(', ')}")
      end

      # Story 5.1: Check if session is in assessment phase
      # Assessment phase starts after insurance is verified
      #
      # @param session [OnboardingSession] Session to check
      # @return [Boolean] True if in assessment phase
      def in_assessment_phase?(session)
        # Check if insurance is verified
        insurance = session.insurance
        return false unless insurance&.verification_status

        insurance_verified = %w[verified self_pay].include?(insurance.verification_status)
        return false unless insurance_verified

        # Check if assessment exists and is in progress
        assessment = session.assessment
        return true if assessment&.in_progress?

        # Check if we should transition to assessment (insurance complete, no assessment yet)
        session.child.present? && session.parent.present? && assessment.nil?
      end

      # Story 5.1: Handle message in assessment phase
      # Uses assessment-specific AI prompts and response parsing
      #
      # @param session [OnboardingSession] Session
      # @param user_message [Message] User's message
      # @param content [String] Message content
      # @return [Hash] Mutation result
      def handle_assessment_message(session, user_message, content)
        # Initialize assessment context manager
        assessment_context = Assessments::ContextManager.new(session: session)

        # Start assessment if needed
        assessment_context.start_assessment unless assessment_context.assessment.in_progress?

        # Parse the response to get Likert value
        parse_result = Assessments::ResponseParser.parse(content)

        # Store the intent as assessment response
        user_message.update!(
          metadata: (user_message.metadata || {}).merge({
            intent: :assessment_response,
            parsed_value: parse_result[:value],
            confidence: parse_result[:confidence]
          })
        )

        # If we got a valid Likert value, record the response
        if parse_result[:value] && !parse_result[:needs_clarification]
          assessment_context.record_response(
            response_text: content,
            parsed_value: parse_result[:value]
          )
        end

        # Build AI context for assessment
        messages = assessment_context.build_ai_context

        # Generate AI response for next question or clarification
        ai_response = call_ai_service(messages, nil, nil)

        # Store assistant response
        assistant_message = store_assistant_message(session, ai_response[:content])

        # Extend session expiration
        session.extend_expiration
        session.save!

        # Trigger subscriptions
        trigger_subscription(session, assistant_message)
        trigger_assessment_subscription(session, assessment_context.assessment)

        # Log activity
        log_message_activity(session, user_message, assistant_message)

        {
          user_message: user_message,
          assistant_message: assistant_message,
          errors: []
        }
      end

      # Trigger assessment subscription for progress updates
      def trigger_assessment_subscription(session, assessment)
        DaybreakHealthBackendSchema.subscriptions.trigger(
          "assessmentUpdated",
          { session_id: "sess_#{session.id.gsub('-', '')}" },
          assessment
        )
      rescue StandardError => e
        Rails.logger.warn("Assessment subscription trigger failed: #{e.message}")
      end
    end
  end
end
