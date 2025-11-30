# frozen_string_literal: true

module Subscriptions
  # MessageReceived subscription for real-time message delivery
  #
  # Acceptance Criteria:
  # - AC3: Response streamed via GraphQL subscription when AI responds
  #
  # Authorization:
  # - Verifies session ownership to prevent cross-session access
  # - Uses session_id parameter for subscription filtering
  #
  # Usage:
  #   subscription {
  #     messageReceived(sessionId: "sess_123") {
  #       id
  #       role
  #       content
  #       createdAt
  #     }
  #   }
  #
  # Triggered by:
  #   DaybreakHealthBackendSchema.subscriptions.trigger(
  #     "messageReceived",
  #     { session_id: "sess_123" },
  #     message_object
  #   )
  class MessageReceived < GraphQL::Schema::Subscription
    description "Subscribe to new messages in a conversation"

    # Argument
    argument :session_id, ID, required: true, description: "Session ID (with sess_ prefix)"

    # Return type
    field :id, ID, null: false, description: "Message ID"
    field :role, String, null: false, description: "Message role (user, assistant, system)"
    field :content, String, null: false, description: "Message content"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When message was created"
    field :metadata, GraphQL::Types::JSON, null: true, description: "Additional message metadata"

    # Called when client subscribes
    # Authorizes access to session before allowing subscription
    #
    # @param session_id [String] Session ID with sess_ prefix
    # @return [Object] Subscription object or raises error if unauthorized
    def subscribe(session_id:)
      # Extract UUID from session_id
      uuid = extract_uuid(session_id)

      # Find session and verify access
      session = OnboardingSession.find(uuid)
      authorize_session!(session)

      # Return subscription object
      # The actual message will be delivered via trigger
      :no_response
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError, "Session not found"
    rescue GraphQL::ExecutionError => e
      raise e
    rescue StandardError => e
      Rails.logger.error("MessageReceived subscription error: #{e.message}")
      raise GraphQL::ExecutionError, "Failed to subscribe to messages"
    end

    # Called when subscription is triggered
    # Returns the message to be sent to the client
    #
    # @return [Message] The message object
    def update(session_id:)
      # Return the message object that was passed to trigger
      object
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
    # Ensures user can only subscribe to their own session's messages
    # HIPAA Compliance: Prevents cross-session PHI access
    #
    # @param session [OnboardingSession] Session to authorize
    # @raise [GraphQL::ExecutionError] If unauthorized
    def authorize_session!(session)
      # Verify JWT token is present and valid
      current_session_id = context[:current_session_id]

      if current_session_id.blank?
        raise GraphQL::ExecutionError, "Authentication required"
      end

      # Verify session belongs to current user (session ID must match)
      # This prevents users from subscribing to other users' sessions (HIPAA)
      unless session.id.to_s == current_session_id.to_s
        Rails.logger.warn("Unauthorized subscription attempt: requested #{session.id}, authenticated as #{current_session_id}")
        raise GraphQL::ExecutionError, "Unauthorized access to session"
      end
    end
  end
end
