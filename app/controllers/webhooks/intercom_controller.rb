# frozen_string_literal: true

module Webhooks
  # Intercom webhook handler
  # Story 7.3: Support Request Tracking
  #
  # Handles Intercom webhook events for support request tracking:
  # - conversation.user.created: Create SupportRequest record
  # - conversation.user.replied: Update timestamps
  # - conversation.admin.closed: Mark resolved: true
  #
  # Security:
  # - Verifies HMAC signature using X-Hub-Signature header
  # - Uses ENV['INTERCOM_WEBHOOK_SECRET'] for signature verification
  #
  # Expected webhook payload structure:
  # {
  #   "type": "notification_event",
  #   "topic": "conversation.user.created",
  #   "data": {
  #     "item": {
  #       "id": "123456",
  #       "user": {
  #         "custom_attributes": {
  #           "session_id": "uuid",
  #           "source": "insurance-verification"
  #         }
  #       }
  #     }
  #   }
  # }
  #
  class IntercomController < ApplicationController
    # Verify webhook signature before processing
    before_action :verify_signature

    # Handle incoming Intercom webhook events
    #
    # @return [void] Returns 200 OK to Intercom
    def create
      payload = parsed_payload

      case payload['topic']
      when 'conversation.user.created'
        handle_conversation_created(payload)
      when 'conversation.user.replied'
        handle_conversation_replied(payload)
      when 'conversation.admin.closed'
        handle_conversation_closed(payload)
      else
        Rails.logger.info("Unhandled webhook topic: #{payload['topic']}")
      end

      # Always return 200 to prevent retries
      head :ok
    rescue StandardError => e
      # Log error but still return 200 to prevent retries
      Rails.logger.error("Intercom webhook error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      head :ok
    end

    private

    # Verify HMAC signature from Intercom
    #
    # Compares the signature from X-Hub-Signature header with
    # computed HMAC using the webhook secret.
    #
    # @raise [ActionController::BadRequest] If signature is invalid
    def verify_signature
      signature = request.headers['X-Hub-Signature']

      unless signature.present?
        Rails.logger.warn('Intercom webhook missing signature')
        render json: { error: 'Missing signature' }, status: :unauthorized
        return
      end

      body = request.raw_post
      secret = ENV['INTERCOM_WEBHOOK_SECRET']

      unless secret.present?
        Rails.logger.error('INTERCOM_WEBHOOK_SECRET not configured')
        render json: { error: 'Server configuration error' }, status: :internal_server_error
        return
      end

      expected = OpenSSL::HMAC.hexdigest('sha1', secret, body)
      expected_signature = "sha1=#{expected}"

      unless Rack::Utils.secure_compare(signature, expected_signature)
        Rails.logger.warn('Intercom webhook signature mismatch')
        render json: { error: 'Invalid signature' }, status: :unauthorized
        return
      end
    end

    # Parse the webhook payload
    #
    # @return [Hash] Parsed JSON payload
    def parsed_payload
      @parsed_payload ||= JSON.parse(request.raw_post)
    end

    # Handle conversation.user.created event
    #
    # Creates a SupportRequest record and flags the session
    #
    # @param payload [Hash] Webhook payload
    def handle_conversation_created(payload)
      conversation_data = extract_conversation_data(payload)
      return unless conversation_data[:session_id].present?

      session = OnboardingSession.find_by(id: conversation_data[:session_id])
      unless session
        Rails.logger.warn("Session not found: #{conversation_data[:session_id]}")
        return
      end

      # Create support request
      support_request = session.support_requests.create!(
        intercom_conversation_id: conversation_data[:conversation_id],
        source: conversation_data[:source] || 'unknown',
        resolved: false
      )

      # Flag session as contacted support
      session.update!(contacted_support: true)

      Rails.logger.info(
        "Support request created: #{support_request.id} for session #{session.id}"
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to create support request: #{e.message}")
    end

    # Handle conversation.user.replied event
    #
    # Updates the support request's updated_at timestamp
    #
    # @param payload [Hash] Webhook payload
    def handle_conversation_replied(payload)
      conversation_data = extract_conversation_data(payload)
      return unless conversation_data[:conversation_id].present?

      support_request = SupportRequest.find_by(
        intercom_conversation_id: conversation_data[:conversation_id]
      )

      if support_request
        support_request.touch
        Rails.logger.info(
          "Support request updated: #{support_request.id}"
        )
      else
        Rails.logger.warn(
          "Support request not found for conversation: #{conversation_data[:conversation_id]}"
        )
      end
    end

    # Handle conversation.admin.closed event
    #
    # Marks the support request as resolved
    #
    # @param payload [Hash] Webhook payload
    def handle_conversation_closed(payload)
      conversation_data = extract_conversation_data(payload)
      return unless conversation_data[:conversation_id].present?

      support_request = SupportRequest.find_by(
        intercom_conversation_id: conversation_data[:conversation_id]
      )

      if support_request
        support_request.mark_resolved!
        Rails.logger.info(
          "Support request resolved: #{support_request.id}"
        )
      else
        Rails.logger.warn(
          "Support request not found for conversation: #{conversation_data[:conversation_id]}"
        )
      end
    end

    # Extract conversation data from webhook payload
    #
    # @param payload [Hash] Webhook payload
    # @return [Hash] Extracted data with keys: conversation_id, session_id, source
    def extract_conversation_data(payload)
      item = payload.dig('data', 'item') || {}
      conversation_id = item['id']

      # Extract custom attributes from user
      user = item['user'] || {}
      custom_attrs = user['custom_attributes'] || {}

      {
        conversation_id: conversation_id,
        session_id: custom_attrs['session_id'],
        source: custom_attrs['source']
      }
    end
  end
end
