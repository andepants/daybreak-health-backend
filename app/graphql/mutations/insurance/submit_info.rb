# frozen_string_literal: true

module Mutations
  module Insurance
    class SubmitInfo < GraphQL::Schema::Mutation
      description "Submit or update insurance information manually"

      # Input
      argument :session_id, ID, required: true, description: "Session ID"
      argument :payer_name, String, required: false, description: "Insurance payer/company name"
      argument :member_id, String, required: false, description: "Member ID (6-20 alphanumeric)"
      argument :group_number, String, required: false, description: "Group number (4-15 alphanumeric)"
      argument :subscriber_name, String, required: false, description: "Name on insurance policy"
      argument :subscriber_dob, String, required: false, description: "Subscriber date of birth (YYYY-MM-DD)"

      # Output
      field :insurance, Types::InsuranceType, null: true, description: "Updated insurance record"
      field :pre_populated_from_ocr, Boolean, null: false, description: "Whether fields were pre-populated from OCR data"
      field :errors, [Types::FieldErrorType], null: false, description: "List of validation errors"

      def resolve(session_id:, **insurance_params)
        # Extract UUID from session ID
        uuid = extract_uuid_from_session_id(session_id)

        # Find session
        session = OnboardingSession.find_by(id: uuid)
        unless session
          return {
            insurance: nil,
            pre_populated_from_ocr: false,
            errors: [{ field: "session_id", message: "Session not found" }]
          }
        end

        # Check authorization
        unless authorized?(session)
          return {
            insurance: nil,
            pre_populated_from_ocr: false,
            errors: [{ field: "session_id", message: "Unauthorized" }]
          }
        end

        # Check if session is expired
        if session.past_expiration?
          return {
            insurance: nil,
            pre_populated_from_ocr: false,
            errors: [{ field: "session_id", message: "Session has expired" }]
          }
        end

        # Find or create insurance record
        insurance = session.insurance || session.build_insurance

        # Check for OCR pre-population
        ocr_available = insurance.ocr_data_available?

        # Filter out nil values (support partial saves)
        params_to_update = insurance_params.compact

        # Update insurance with manual entry
        insurance.assign_attributes(params_to_update)

        # Track data sources
        data_sources = insurance.verification_result&.dig("data_sources") || {}
        params_to_update.each_key do |field|
          data_sources[field.to_s] = "manual"
        end

        insurance.verification_result = (insurance.verification_result || {}).merge(
          "data_sources" => data_sources,
          "manual_entry_at" => Time.current.iso8601
        )

        # Update status if all required fields are present
        if insurance.member_id.present? && insurance.payer_name.present?
          insurance.verification_status = :manual_entry_complete
        elsif insurance.persisted?
          # Only update to manual_entry if already saved and not complete
          insurance.verification_status = :manual_entry unless insurance.manual_entry_complete?
        end

        if insurance.save
          # Audit log
          create_audit_log(session, insurance, params_to_update, ocr_available)

          {
            insurance: insurance,
            pre_populated_from_ocr: ocr_available,
            errors: []
          }
        else
          # Return validation errors in field-specific format
          field_errors = insurance.errors.map do |error|
            { field: error.attribute.to_s, message: error.message }
          end

          {
            insurance: nil,
            pre_populated_from_ocr: ocr_available,
            errors: field_errors
          }
        end
      rescue StandardError => e
        Rails.logger.error("Error in SubmitInfo mutation: #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n"))

        {
          insurance: nil,
          pre_populated_from_ocr: false,
          errors: [{ field: "base", message: "An error occurred while saving insurance information" }]
        }
      end

      private

      def extract_uuid_from_session_id(session_id)
        clean_id = session_id.to_s.gsub(/^sess_/, "")
        # Check if it's already a UUID format
        return clean_id if clean_id.include?("-")

        # Convert CUID format to UUID
        "#{clean_id[0..7]}-#{clean_id[8..11]}-#{clean_id[12..15]}-#{clean_id[16..19]}-#{clean_id[20..31]}"
      end

      def authorized?(session)
        # For now, allow any valid session
        # In production, this would check context[:current_session]
        session.present?
      end

      def create_audit_log(session, insurance, params_updated, ocr_pre_populated)
        AuditLog.create!(
          onboarding_session_id: session.id,
          action: "INSURANCE_MANUAL_ENTRY",
          resource: "Insurance",
          resource_id: insurance.id,
          details: {
            fields_updated: params_updated.keys.map(&:to_s),
            ocr_pre_populated: ocr_pre_populated,
            status: insurance.verification_status,
            timestamp: Time.current.iso8601
          },
          ip_address: context[:ip_address]
        )
      end
    end
  end
end
