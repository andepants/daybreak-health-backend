# frozen_string_literal: true

module Mutations
  module Intake
    class SubmitParentInfo < GraphQL::Schema::Mutation
      description "Submit parent/guardian information during intake"

      # Input
      argument :session_id, ID, required: true, description: "Session ID (CUID format with sess_ prefix)"
      argument :parent_info, Types::Inputs::ParentInput, required: true, description: "Parent information to save"

      # Output
      field :parent, Types::ParentType, null: true, description: "Created or updated parent record"
      field :errors, [String], null: false, description: "List of validation errors"

      def resolve(session_id:, parent_info:)
        # Strip sess_ prefix and re-add hyphens to get UUID
        uuid = extract_uuid_from_session_id(session_id)

        # Find session
        session = OnboardingSession.find_by(id: uuid)
        unless session
          return { parent: nil, errors: ["Session not found"] }
        end

        # Check if session is expired
        if session.past_expiration?
          return { parent: nil, errors: ["Session has expired"] }
        end

        # Normalize phone to E.164 format
        normalized_phone = normalize_phone(parent_info.phone)
        unless normalized_phone
          return { parent: nil, errors: ["Phone number must be in valid E.164 format (e.g., +15551234567)"] }
        end

        # Validate email format
        unless valid_email?(parent_info.email)
          return { parent: nil, errors: ["Email must be in valid RFC 5322 format"] }
        end

        # Validate relationship enum
        relationship_key = parent_info.relationship.to_s.downcase
        unless Parent.relationships.key?(relationship_key)
          valid_values = Parent.relationships.keys.join(', ')
          return { parent: nil, errors: ["Relationship must be one of: #{valid_values}"] }
        end

        # Create or update parent record
        parent = session.parent || session.build_parent
        parent.assign_attributes(
          first_name: parent_info.first_name,
          last_name: parent_info.last_name,
          email: parent_info.email,
          phone: normalized_phone,
          relationship: relationship_key,
          is_guardian: parent_info.is_guardian
        )

        if parent.save
          # Update session progress
          update_session_progress(session)

          # Trigger audit log
          create_audit_log(session, parent)

          # Queue session recovery email
          queue_recovery_email(session, parent) if parent.email.present?

          { parent: parent, errors: [] }
        else
          { parent: nil, errors: parent.errors.full_messages }
        end
      rescue StandardError => e
        Rails.logger.error("Error in SubmitParentInfo mutation: #{e.message}")
        { parent: nil, errors: ["An error occurred while saving parent information"] }
      end

      private

      def extract_uuid_from_session_id(session_id)
        # Remove sess_ prefix and add hyphens back to UUID
        clean_id = session_id.to_s.gsub(/^sess_/, '')
        # UUID format: 8-4-4-4-12
        "#{clean_id[0..7]}-#{clean_id[8..11]}-#{clean_id[12..15]}-#{clean_id[16..19]}-#{clean_id[20..31]}"
      end

      def normalize_phone(phone)
        parsed = Phonelib.parse(phone, 'US')
        return nil unless parsed.valid?
        parsed.e164
      end

      def valid_email?(email)
        email.match?(URI::MailTo::EMAIL_REGEXP)
      end

      def update_session_progress(session)
        # Add parentInfoCollected flag to progress
        current_progress = session.progress || {}
        updated_progress = current_progress.deep_merge(
          intake: { parentInfoCollected: true }
        )

        session.progress = updated_progress
        session.extend_expiration(1.hour)
        session.save!
      end

      def create_audit_log(session, parent)
        AuditLog.create!(
          onboarding_session_id: session.id,
          action: 'PARENT_INFO_SUBMITTED',
          resource: 'Parent',
          resource_id: parent.id,
          details: {
            has_email: parent.email.present?,
            has_phone: parent.phone.present?,
            relationship: parent.relationship,
            is_guardian: parent.is_guardian,
            timestamp: Time.current.iso8601
          }
        )
      end

      def queue_recovery_email(session, parent)
        # Queue job to send session recovery email
        # Full implementation in Story 6.1
        SessionRecoveryEmailJob.perform_later(session.id, parent.email)
      rescue StandardError => e
        # Don't fail the mutation if email queueing fails
        Rails.logger.error("Failed to queue recovery email: #{e.message}")
      end
    end
  end
end
