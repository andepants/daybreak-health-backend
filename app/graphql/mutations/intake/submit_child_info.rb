# frozen_string_literal: true

module Mutations
  module Intake
    # Submit child information mutation
    # AC 3.7.1, 3.7.2, 3.7.9: Collect and store child demographics and school info
    class SubmitChildInfo < GraphQL::Schema::Mutation
      description "Submit child information during intake"

      # Input
      argument :session_id, ID, required: true, description: "Session ID (CUID format with sess_ prefix)", camelize: false
      argument :child_info, Types::Inputs::ChildInput, required: true, description: "Child information to save", camelize: false

      # Output
      field :child, Types::ChildType, null: true, description: "Created or updated child record"
      field :session, Types::OnboardingSessionType, null: true, description: "Updated session with progress"
      field :errors, [ String ], null: false, description: "List of validation errors"

      def resolve(session_id:, child_info:)
        # Strip sess_ prefix and re-add hyphens to get UUID
        uuid = extract_uuid_from_session_id(session_id)

        # Find session
        session = OnboardingSession.find_by(id: uuid)
        unless session
          return { child: nil, session: nil, errors: [ "Session not found" ] }
        end

        # Check if session is expired
        if session.past_expiration?
          return { child: nil, session: nil, errors: [ "Session has expired" ] }
        end

        # Validate date of birth format (ISO 8601: YYYY-MM-DD)
        unless valid_date_format?(child_info.date_of_birth)
          return { child: nil, session: nil, errors: [ "Date of birth must be in ISO 8601 format (YYYY-MM-DD)" ] }
        end

        # Create or update child record
        child = session.child || session.build_child
        child.assign_attributes(
          first_name: child_info.first_name,
          last_name: child_info.last_name,
          date_of_birth: child_info.date_of_birth,
          gender: child_info.gender,
          school_name: child_info.school_name,
          grade: child_info.grade,
          primary_concerns: child_info.primary_concerns
        )

        # AC 3.7.10: Validations will be checked on save
        # - DOB not in future
        # - Age within service range (5-18)
        if child.save
          # AC 3.7.9: Update session progress when child info complete
          update_session_progress(session)

          # AC 3.7.9: Create audit log entry
          create_audit_log(session, child)

          { child: child, session: session.reload, errors: [] }
        else
          # AC 3.7.10: Return clear validation errors to AI for parent feedback
          { child: nil, session: nil, errors: child.errors.full_messages }
        end
      rescue StandardError => e
        Rails.logger.error("Error in SubmitChildInfo mutation: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        { child: nil, session: nil, errors: [ "An error occurred while saving child information" ] }
      end

      private

      # Extract UUID from session ID (removes sess_ prefix and adds hyphens)
      def extract_uuid_from_session_id(session_id)
        # Remove sess_ prefix and add hyphens back to UUID
        clean_id = session_id.to_s.gsub(/^sess_/, "")
        # UUID format: 8-4-4-4-12
        "#{clean_id[0..7]}-#{clean_id[8..11]}-#{clean_id[12..15]}-#{clean_id[16..19]}-#{clean_id[20..31]}"
      end

      # Validate date format (ISO 8601: YYYY-MM-DD)
      def valid_date_format?(date_string)
        return false if date_string.blank?

        Date.parse(date_string)
        true
      rescue ArgumentError, TypeError
        false
      end

      # Update session progress to track child info collection
      # AC 3.7.9: Session progress updated when child info complete
      def update_session_progress(session)
        current_progress = session.progress || {}
        updated_progress = current_progress.deep_merge(
          intake: { childInfoCollected: true }
        )

        session.progress = updated_progress
        session.extend_expiration(1.hour)
        session.save!
      end

      # Create audit log for child information submission
      # AC 3.7.9: Audit log entry created with action CHILD_INFO_SUBMITTED
      # AC: PHI-safe logging (log existence flags, not actual values)
      def create_audit_log(session, child)
        AuditLog.create!(
          onboarding_session_id: session.id,
          action: "CHILD_INFO_SUBMITTED",
          resource: "Child",
          resource_id: child.id,
          details: {
            has_first_name: child.first_name.present?,
            has_last_name: child.last_name.present?,
            has_date_of_birth: child.date_of_birth.present?,
            age: child.age, # Age is safe to log (not direct PHI)
            has_gender: child.gender.present?,
            has_school_name: child.school_name.present?,
            has_grade: child.grade.present?,
            has_primary_concerns: child.primary_concerns.present?,
            timestamp: Time.current.iso8601
          }
        )
      end
    end
  end
end
