# frozen_string_literal: true

module Mutations
  module Insurance
    class UploadCard < GraphQL::Schema::Mutation
      description "Upload insurance card images (front and optional back)"

      # Input
      argument :session_id, ID, required: true, description: "Session ID (CUID format with sess_ prefix)"
      argument :front_image, ApolloUploadServer::Upload, required: true, description: "Front image of insurance card"
      argument :back_image, ApolloUploadServer::Upload, required: false, description: "Back image of insurance card (optional)"

      # Output
      field :insurance, Types::InsuranceType, null: true, description: "Updated insurance record with presigned URLs"
      field :errors, [String], null: false, description: "List of validation errors"

      def resolve(session_id:, front_image:, back_image: nil)
        # Extract UUID from session ID
        uuid = extract_uuid_from_session_id(session_id)

        # Find session
        session = OnboardingSession.find_by(id: uuid)
        unless session
          return { insurance: nil, errors: ["Session not found"] }
        end

        # Check authorization
        unless authorized?(session)
          return { insurance: nil, errors: ["Unauthorized"] }
        end

        # Check if session is expired
        if session.past_expiration?
          return { insurance: nil, errors: ["Session has expired"] }
        end

        # Validate files
        validator = ::InsuranceCard::FileValidator.new
        validator.validate!(front_image)
        validator.validate!(back_image) if back_image

        # Find or create insurance record
        insurance = session.insurance || session.create_insurance!(
          verification_status: :pending
        )

        # Process and attach images
        processor = ::InsuranceCard::ImageProcessor.new

        # Process front image (convert HEIC if needed, strip metadata)
        processed_front = processor.process(front_image)
        insurance.card_image_front.attach(
          io: processed_front[:io],
          filename: "#{session.id}_front.jpg",
          content_type: processed_front[:content_type]
        )

        # Process back image if provided
        if back_image
          processed_back = processor.process(back_image)
          insurance.card_image_back.attach(
            io: processed_back[:io],
            filename: "#{session.id}_back.jpg",
            content_type: processed_back[:content_type]
          )
        end

        # Update status to pending if it was nil or not already in progress
        insurance.update!(verification_status: :pending) unless insurance.in_progress?

        # Queue OCR processing
        OcrProcessingJob.perform_later(insurance.id)

        # Create audit log
        create_audit_log(session, insurance, back_image.present?)

        { insurance: insurance, errors: [] }
      rescue GraphQL::ExecutionError => e
        # Re-raise GraphQL execution errors (validation errors from FileValidator)
        raise e
      rescue Vips::Error => e
        # libvips processing error (HEIC conversion, metadata stripping)
        Rails.logger.error("UploadCard Vips error: #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n"))
        { insurance: nil, errors: ["Image processing failed. Please try a different image format (JPEG or PNG)."] }
      rescue ActiveStorage::FileNotFoundError => e
        Rails.logger.error("UploadCard storage error: #{e.message}")
        { insurance: nil, errors: ["Failed to store uploaded file. Please try again."] }
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("UploadCard validation error: #{e.message}")
        { insurance: nil, errors: [e.record.errors.full_messages.join(", ")] }
      rescue StandardError => e
        Rails.logger.error("Error in UploadCard mutation: #{e.class.name} - #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n"))
        # In development, expose the actual error for debugging
        error_message = if Rails.env.development?
                          "Upload error: #{e.class.name} - #{e.message}"
                        else
                          "An error occurred while uploading images"
                        end
        { insurance: nil, errors: [error_message] }
      end

      private

      def extract_uuid_from_session_id(session_id)
        clean_id = session_id.to_s.gsub(/^sess_/, "")
        "#{clean_id[0..7]}-#{clean_id[8..11]}-#{clean_id[12..15]}-#{clean_id[16..19]}-#{clean_id[20..31]}"
      end

      def authorized?(session)
        # For now, allow any valid session
        # In production, this would check context[:current_session]
        session.present?
      end

      def create_audit_log(session, insurance, has_back_image)
        AuditLog.create!(
          onboarding_session_id: session.id,
          action: "INSURANCE_CARD_UPLOADED",
          resource: "Insurance",
          resource_id: insurance.id,
          details: {
            has_front_image: true,
            has_back_image: has_back_image,
            verification_status: insurance.verification_status,
            timestamp: Time.current.iso8601
          },
          ip_address: context[:ip_address]
        )
      end
    end
  end
end
