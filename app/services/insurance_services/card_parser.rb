# frozen_string_literal: true

module InsuranceServices
  # Parses insurance card images using AWS Textract OCR
  #
  # Extracts key fields from insurance cards:
  # - member_id: Member/Subscriber ID
  # - group_number: Group number
  # - payer_name: Insurance company name
  # - subscriber_name: Name on card
  #
  # @example
  #   parser = Insurance::CardParser.new(insurance)
  #   result = parser.call
  #   # => { status: :ocr_complete, data: {...}, raw: {...} }
  #
  # @see Story 4.2: OCR Insurance Card Extraction
  class CardParser < BaseService
    MIN_CONFIDENCE = 85.0

    # Field label mappings for insurance card parsing
    # Each field maps to an array of possible label variations
    FIELD_MAPPINGS = {
      member_id: [
        "Member ID", "ID#", "Subscriber ID", "Member Number",
        "ID Number", "Member #", "ID", "Identification Number"
      ],
      group_number: [
        "Group", "Group#", "Group No", "Group Number", "Grp",
        "Group ID", "GRP#", "Plan Group"
      ],
      payer_name: [
        "Plan Name", "Insurance Company", "Carrier", "Payer",
        "Health Plan", "Plan", "Insurance Plan"
      ],
      subscriber_name: [
        "Name", "Member Name", "Subscriber", "Subscriber Name",
        "Primary Subscriber", "Member"
      ]
    }.freeze

    # @param insurance [Insurance] The insurance record with attached card images
    def initialize(insurance)
      @insurance = insurance
      @textract = AwsClients.textract
    end

    # Parse insurance card images and extract fields
    #
    # @return [Hash] Parsed result with :status, :data, and :raw keys
    def call
      front_result = analyze_image(@insurance.card_image_front)
      back_result = @insurance.card_image_back.attached? ?
        analyze_image(@insurance.card_image_back) : nil

      extracted = extract_fields(front_result, back_result)

      {
        status: determine_status(extracted),
        data: extracted,
        raw: { front: serialize_response(front_result), back: serialize_response(back_result) }
      }
    end

    private

    # Analyze a single image using AWS Textract
    #
    # @param attachment [ActiveStorage::Attached] The attached image
    # @return [Aws::Textract::Types::AnalyzeDocumentResponse] Textract response
    def analyze_image(attachment)
      blob = attachment.blob

      # Determine document source based on Active Storage service
      document = if using_s3_storage?
                   # For S3 storage, reference the object directly (more efficient)
                   {
                     s3_object: {
                       bucket: s3_bucket_name,
                       name: blob.key
                     }
                   }
                 else
                   # For local/disk storage, download and send bytes
                   # AWS SDK handles base64 encoding automatically
                   { bytes: blob.download }
                 end

      @textract.analyze_document({
        document: document,
        feature_types: ["FORMS"]
      })
    end

    # Check if Active Storage is configured to use S3
    #
    # @return [Boolean] true if using S3/amazon service
    def using_s3_storage?
      service_name = Rails.configuration.active_storage.service
      service_name.to_s == "amazon"
    end

    # Get S3 bucket name from Active Storage configuration
    #
    # @return [String] S3 bucket name
    def s3_bucket_name
      config = Rails.configuration.active_storage.service_configurations
      amazon_config = config["amazon"] || config[:amazon]
      amazon_config["bucket"] || amazon_config[:bucket] || ENV["S3_BUCKET"]
    end

    # Extract insurance fields from Textract responses
    #
    # @param front_result [Aws::Textract::Types::AnalyzeDocumentResponse] Front card result
    # @param back_result [Aws::Textract::Types::AnalyzeDocumentResponse, nil] Back card result
    # @return [Hash] Extracted fields with confidence scores
    def extract_fields(front_result, back_result)
      fields = {}
      confidence = {}

      FIELD_MAPPINGS.each do |field, labels|
        result = find_field_value(front_result, labels) ||
                 (back_result && find_field_value(back_result, labels))

        if result
          fields[field] = result[:value]
          confidence[field] = result[:confidence]
        end
      end

      # Try to extract payer name from document text if not found in key-value pairs
      if fields[:payer_name].blank?
        payer = extract_payer_from_text(front_result)
        if payer
          fields[:payer_name] = payer[:value]
          confidence[:payer_name] = payer[:confidence]
        end
      end

      low_confidence_fields = confidence.select { |_, v| v < MIN_CONFIDENCE }.keys

      {
        extracted_fields: fields,
        confidence_scores: confidence,
        low_confidence_fields: low_confidence_fields,
        needs_review: low_confidence_fields.any?
      }
    end

    # Find a field value from Textract key-value pairs
    #
    # @param textract_result [Aws::Textract::Types::AnalyzeDocumentResponse] Textract response
    # @param labels [Array<String>] Possible labels for the field
    # @return [Hash, nil] Hash with :value and :confidence, or nil
    def find_field_value(textract_result, labels)
      blocks_by_id = build_blocks_index(textract_result.blocks)

      textract_result.blocks.each do |block|
        next unless block.block_type == "KEY_VALUE_SET"
        next unless block.entity_types&.include?("KEY")

        key_text = extract_text_from_block(blocks_by_id, block)
        next if key_text.blank?

        matched = labels.any? do |label|
          key_text.downcase.include?(label.downcase)
        end
        next unless matched

        value_block = find_value_block(blocks_by_id, block)
        next unless value_block

        value_text = extract_text_from_block(blocks_by_id, value_block)
        next if value_text.blank?

        return {
          value: value_text.strip,
          confidence: block.confidence || 0.0
        }
      end

      nil
    end

    # Build an index of blocks by ID for efficient lookup
    #
    # @param blocks [Array<Aws::Textract::Types::Block>] All blocks
    # @return [Hash<String, Aws::Textract::Types::Block>] Blocks indexed by ID
    def build_blocks_index(blocks)
      blocks.each_with_object({}) { |b, h| h[b.id] = b }
    end

    # Extract text from a block by following CHILD relationships
    #
    # @param blocks_by_id [Hash<String, Aws::Textract::Types::Block>] Blocks index
    # @param block [Aws::Textract::Types::Block] The block to extract text from
    # @return [String] Extracted text
    def extract_text_from_block(blocks_by_id, block)
      text_parts = []

      block.relationships&.each do |rel|
        next unless rel.type == "CHILD"

        rel.ids.each do |child_id|
          child = blocks_by_id[child_id]
          next unless child

          if child.block_type == "WORD" || child.block_type == "SELECTION_ELEMENT"
            text_parts << (child.text || "")
          end
        end
      end

      text_parts.join(" ")
    end

    # Find the VALUE block paired with a KEY block
    #
    # @param blocks_by_id [Hash<String, Aws::Textract::Types::Block>] Blocks index
    # @param key_block [Aws::Textract::Types::Block] The KEY block
    # @return [Aws::Textract::Types::Block, nil] The VALUE block or nil
    def find_value_block(blocks_by_id, key_block)
      key_block.relationships&.each do |rel|
        next unless rel.type == "VALUE"

        rel.ids.each do |value_id|
          value_block = blocks_by_id[value_id]
          return value_block if value_block&.block_type == "KEY_VALUE_SET"
        end
      end

      nil
    end

    # Extract payer name from document text (usually at top of card)
    # Fallback when payer not found in key-value pairs
    #
    # @param textract_result [Aws::Textract::Types::AnalyzeDocumentResponse] Textract response
    # @return [Hash, nil] Hash with :value and :confidence, or nil
    def extract_payer_from_text(textract_result)
      # Look for LINE blocks at the top of the document
      line_blocks = textract_result.blocks.select { |b| b.block_type == "LINE" }
      return nil if line_blocks.empty?

      # Sort by vertical position (top to bottom)
      sorted_lines = line_blocks.sort_by do |block|
        block.geometry&.bounding_box&.top || 0
      end

      # Get the first few lines (typically contain payer name/logo text)
      top_lines = sorted_lines.first(3)

      # Look for known payer patterns
      payer_patterns = [
        /\b(Aetna|UnitedHealthcare|UHC|BCBS|Blue Cross|Blue Shield|Cigna|Humana|Kaiser|Anthem|Molina)\b/i
      ]

      top_lines.each do |line|
        text = line.text
        next if text.blank?

        payer_patterns.each do |pattern|
          if text.match?(pattern)
            return {
              value: text.strip,
              confidence: line.confidence || 80.0
            }
          end
        end
      end

      # If no pattern match, return first non-trivial line as potential payer
      first_line = top_lines.find { |l| l.text.present? && l.text.length > 3 }
      return nil unless first_line

      {
        value: first_line.text.strip,
        confidence: (first_line.confidence || 70.0) * 0.8 # Reduce confidence for heuristic match
      }
    end

    # Determine OCR status based on extraction results
    #
    # @param extracted [Hash] Extracted data with :needs_review flag
    # @return [Symbol] :ocr_complete or :ocr_needs_review
    def determine_status(extracted)
      extracted[:needs_review] ? :ocr_needs_review : :ocr_complete
    end

    # Serialize Textract response for storage in JSONB
    # Only keeps essential data to avoid storing large raw responses
    #
    # @param response [Aws::Textract::Types::AnalyzeDocumentResponse, nil] Textract response
    # @return [Hash, nil] Serialized response
    def serialize_response(response)
      return nil unless response

      {
        document_metadata: {
          pages: response.document_metadata&.pages
        },
        blocks_count: response.blocks&.size,
        analyze_document_model_version: response.analyze_document_model_version
      }
    end
  end
end
