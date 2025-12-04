# frozen_string_literal: true

module InsuranceServices
  # Parses insurance card images using OpenAI Vision API
  #
  # Alternative to AWS Textract for OCR processing, especially useful for:
  # - Local development (avoids AWS SSL certificate issues)
  # - Fallback when Textract is unavailable
  # - Better understanding of complex card layouts
  #
  # Extracts key fields from insurance cards:
  # - member_id: Member/Subscriber ID
  # - group_number: Group number
  # - payer_name: Insurance company name
  # - subscriber_name: Name on card
  #
  # @example
  #   parser = InsuranceServices::OpenaiCardParser.new(insurance)
  #   result = parser.call
  #   # => { status: :ocr_complete, data: {...}, raw: {...} }
  #
  # @see Story 4.2: OCR Insurance Card Extraction
  class OpenaiCardParser < BaseService
    MIN_CONFIDENCE = 85.0

    # OpenAI model to use for vision tasks
    VISION_MODEL = "gpt-4o"

    # System prompt for insurance card extraction
    SYSTEM_PROMPT = <<~PROMPT
      You are an expert at extracting information from insurance cards.
      Analyze the provided insurance card image(s) and extract the following fields:

      1. member_id - The Member ID, Subscriber ID, or ID Number
      2. group_number - The Group Number or Plan Group
      3. payer_name - The Insurance Company name (e.g., Blue Cross, Aetna, UnitedHealthcare)
      4. subscriber_name - The name of the person on the card

      For each field, also provide a confidence score from 0-100 indicating how confident you are in the extraction.

      Respond in JSON format:
      {
        "extracted_fields": {
          "member_id": "value or null if not found",
          "group_number": "value or null if not found",
          "payer_name": "value or null if not found",
          "subscriber_name": "value or null if not found"
        },
        "confidence_scores": {
          "member_id": 95,
          "group_number": 90,
          "payer_name": 98,
          "subscriber_name": 85
        },
        "notes": "Any relevant observations about the card or extraction"
      }

      Important:
      - Extract exact values as they appear on the card
      - If a field is not visible or unclear, set it to null with low confidence
      - The payer name should be the actual insurance company, not plan type
    PROMPT

    # @param insurance [Insurance] The insurance record with attached card images
    def initialize(insurance)
      @insurance = insurance
      @client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    end

    # Parse insurance card images and extract fields
    #
    # @return [Hash] Parsed result with :status, :data, and :raw keys
    def call
      images = build_image_content

      response = @client.chat(
        parameters: {
          model: VISION_MODEL,
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            {
              role: "user",
              content: [
                { type: "text", text: "Please extract the insurance information from the following card image(s):" },
                *images
              ]
            }
          ],
          max_tokens: 1000,
          response_format: { type: "json_object" }
        }
      )

      raw_response = response.dig("choices", 0, "message", "content")
      parsed = JSON.parse(raw_response)

      extracted = process_extraction(parsed)

      {
        status: determine_status(extracted),
        data: extracted,
        raw: { openai_response: parsed }
      }
    rescue OpenAI::Error => e
      Rails.logger.error("OpenAI Vision API error: #{e.message}")
      raise
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse OpenAI response: #{e.message}")
      raise
    end

    private

    # Build image content array for OpenAI API
    #
    # @return [Array<Hash>] Array of image content objects
    def build_image_content
      images = []

      # Add front image (required)
      if @insurance.card_image_front.attached?
        images << build_image_object(@insurance.card_image_front, "Front of insurance card")
      end

      # Add back image (optional)
      if @insurance.card_image_back.attached?
        images << build_image_object(@insurance.card_image_back, "Back of insurance card")
      end

      images
    end

    # Build a single image object for OpenAI API
    #
    # @param attachment [ActiveStorage::Attached] The attached image
    # @param description [String] Description for the image
    # @return [Hash] Image content object
    def build_image_object(attachment, description)
      blob = attachment.blob

      # Download and encode image as base64
      image_data = blob.download
      base64_image = Base64.strict_encode64(image_data)
      mime_type = blob.content_type || "image/jpeg"

      {
        type: "image_url",
        image_url: {
          url: "data:#{mime_type};base64,#{base64_image}",
          detail: "high"
        }
      }
    end

    # Process the extraction response from OpenAI
    #
    # @param parsed [Hash] Parsed JSON response from OpenAI
    # @return [Hash] Processed extraction data
    def process_extraction(parsed)
      fields = parsed["extracted_fields"] || {}
      confidence = parsed["confidence_scores"] || {}

      # Convert string keys to symbols and clean up values
      extracted_fields = {}
      confidence_scores = {}

      %i[member_id group_number payer_name subscriber_name].each do |field|
        key = field.to_s
        value = fields[key]

        # Only include non-null values
        if value.present?
          extracted_fields[field] = value.to_s.strip
          confidence_scores[field] = (confidence[key] || 80.0).to_f
        end
      end

      # Determine low confidence fields
      low_confidence_fields = confidence_scores.select { |_, v| v < MIN_CONFIDENCE }.keys

      {
        extracted_fields: extracted_fields,
        confidence_scores: confidence_scores,
        low_confidence_fields: low_confidence_fields,
        needs_review: low_confidence_fields.any?,
        notes: parsed["notes"]
      }
    end

    # Determine OCR status based on extraction results
    #
    # @param extracted [Hash] Extracted data with :needs_review flag
    # @return [Symbol] :ocr_complete or :ocr_needs_review
    def determine_status(extracted)
      extracted[:needs_review] ? :ocr_needs_review : :ocr_complete
    end
  end
end
