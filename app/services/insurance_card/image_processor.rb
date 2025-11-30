# frozen_string_literal: true

module InsuranceCard
  # Processes insurance card images before attachment
  #
  # Responsibilities:
  # - Convert HEIC/HEIF to JPEG for compatibility
  # - Strip EXIF metadata for privacy/security
  # - Ensure consistent output format
  #
  # @example
  #   processor = InsuranceCard::ImageProcessor.new
  #   result = processor.process(upload)
  #   # => { io: File, content_type: "image/jpeg" }
  class ImageProcessor
    HEIC_TYPES = %w[image/heic image/heif].freeze
    JPEG_QUALITY = 90

    # Process an uploaded image file
    #
    # @param upload [ActionDispatch::Http::UploadedFile] The uploaded file
    # @return [Hash] Processed image with :io and :content_type keys
    def process(upload)
      tempfile = extract_tempfile(upload)
      detected_type = Marcel::MimeType.for(tempfile)

      if heic_type?(detected_type)
        convert_to_jpeg(tempfile)
      else
        strip_metadata(tempfile, detected_type)
      end
    end

    private

    def extract_tempfile(upload)
      upload.respond_to?(:tempfile) ? upload.tempfile : upload
    end

    def heic_type?(mime_type)
      HEIC_TYPES.include?(mime_type)
    end

    def convert_to_jpeg(tempfile)
      processed = ImageProcessing::Vips
        .source(tempfile)
        .convert("jpeg")
        .saver(quality: JPEG_QUALITY, strip: true)
        .call

      { io: File.open(processed.path, "rb"), content_type: "image/jpeg" }
    end

    def strip_metadata(tempfile, content_type)
      # Use vips to strip EXIF metadata
      # The strip option removes all metadata including GPS data
      processed = ImageProcessing::Vips
        .source(tempfile)
        .saver(strip: true)
        .call

      # Determine output content type (vips may have converted format)
      output_type = content_type == "image/png" ? "image/png" : "image/jpeg"

      { io: File.open(processed.path, "rb"), content_type: output_type }
    end
  end
end
