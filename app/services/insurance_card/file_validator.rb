# frozen_string_literal: true

module InsuranceCard
  # Validates insurance card image uploads
  #
  # Validates:
  # - File size (max 10MB) using server-side tempfile size
  # - File type using Marcel magic byte detection (not client-provided content_type)
  #
  # @example
  #   validator = InsuranceCard::FileValidator.new
  #   validator.validate!(upload)  # Raises GraphQL::ExecutionError on failure
  class FileValidator
    MAX_FILE_SIZE = 10.megabytes
    ALLOWED_MIME_TYPES = %w[image/jpeg image/png image/heic image/heif].freeze

    # Validate an uploaded file
    #
    # @param upload [ActionDispatch::Http::UploadedFile] The uploaded file
    # @raise [GraphQL::ExecutionError] If validation fails
    # @return [true] If validation passes
    def validate!(upload)
      return true if upload.nil?

      validate_size!(upload)
      validate_type!(upload)
      true
    end

    private

    def validate_size!(upload)
      tempfile = extract_tempfile(upload)
      actual_size = tempfile.size

      return if actual_size <= MAX_FILE_SIZE

      size_mb = (actual_size.to_f / 1.megabyte).round(1)
      raise GraphQL::ExecutionError.new(
        "File size exceeds 10MB limit (#{size_mb}MB)",
        extensions: { code: "VALIDATION_ERROR", field: "file" }
      )
    end

    def validate_type!(upload)
      tempfile = extract_tempfile(upload)
      detected_type = Marcel::MimeType.for(tempfile)

      return if ALLOWED_MIME_TYPES.include?(detected_type)

      raise GraphQL::ExecutionError.new(
        "Invalid file type '#{detected_type}'. Allowed: JPEG, PNG, HEIC",
        extensions: { code: "VALIDATION_ERROR", field: "file" }
      )
    end

    def extract_tempfile(upload)
      upload.respond_to?(:tempfile) ? upload.tempfile : upload
    end
  end
end
