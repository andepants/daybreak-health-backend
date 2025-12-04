# frozen_string_literal: true

# Job to process insurance card images with OCR
#
# Supports multiple OCR providers:
# - OpenAI Vision (default in development, fallback in production)
# - AWS Textract (default in production)
#
# Extracts insurance information from uploaded card images:
# - member_id, group_number, payer_name, subscriber_name
# - Confidence scores for each extracted field
# - Flags low-confidence extractions for manual review
#
# Configuration via environment:
# - OCR_PROVIDER: 'openai' | 'textract' (default: 'openai')
# - OpenAI Vision is the default due to better accuracy and simpler setup
#
# @example Queue the job
#   OcrProcessingJob.perform_later(insurance.id)
#
# @see Story 4.2: OCR Insurance Card Extraction
class OcrProcessingJob < ApplicationJob
  include GraphqlConcerns::SessionIdParser

  queue_as :insurance

  # Retry up to 3 times for transient failures
  # Note: Using fixed wait time as :exponentially_longer doesn't work with async adapter
  retry_on Aws::Textract::Errors::ProvisionedThroughputExceededException, wait: 5.seconds, attempts: 5
  retry_on Aws::Textract::Errors::ThrottlingException, wait: 5.seconds, attempts: 5

  # Discard if record is deleted
  discard_on ActiveRecord::RecordNotFound

  # Don't retry on permanent failures - record failure and notify
  discard_on Aws::Textract::Errors::InvalidParameterException do |job, error|
    handle_permanent_failure(job.arguments.first, "INVALID_PARAMETER", error.message)
  end
  discard_on Aws::Textract::Errors::InvalidS3ObjectException do |job, error|
    handle_permanent_failure(job.arguments.first, "INVALID_S3_OBJECT", error.message)
  end
  discard_on Aws::Textract::Errors::UnsupportedDocumentException do |job, error|
    handle_permanent_failure(job.arguments.first, "UNSUPPORTED_DOCUMENT", error.message)
  end

  # Catch-all for other errors - record failure after all retries exhausted
  retry_on StandardError, wait: 3.seconds, attempts: 3 do |job, error|
    handle_permanent_failure(job.arguments.first, "UNKNOWN_ERROR", error.message)
  end

  # Timeout for OCR processing
  OCR_TIMEOUT = 60.seconds

  def perform(insurance_id)
    insurance = Insurance.find(insurance_id)

    # Ensure front image is attached
    unless insurance.card_image_front.attached?
      Rails.logger.error("OcrProcessingJob: No front image attached for insurance #{insurance_id}")
      record_failure(insurance, "NO_FRONT_IMAGE", "No front card image attached")
      return
    end

    Rails.logger.info("OcrProcessingJob: Processing insurance #{insurance_id} with provider: #{ocr_provider}")

    # Update status to in_progress
    insurance.update!(verification_status: :in_progress)

    # Parse card images with the configured provider
    result = process_with_provider(insurance)

    # Update insurance with OCR results
    update_insurance_with_results(insurance, result)

    # Trigger GraphQL subscription
    trigger_status_subscription(insurance)

    # Create audit log entry
    create_audit_log(insurance, result)

    Rails.logger.info("OcrProcessingJob: Completed processing for insurance #{insurance_id} - status: #{result[:status]}")
  rescue Timeout::Error
    handle_timeout(insurance)
  rescue Aws::Textract::Errors::ServiceError => e
    handle_textract_error(insurance, e)
  end

  private

  # Determine which OCR provider to use
  #
  # @return [Symbol] :openai or :textract
  def ocr_provider
    provider = ENV.fetch("OCR_PROVIDER", "openai").downcase
    provider == "textract" ? :textract : :openai
  end

  # Process with the selected OCR provider, with fallback support
  #
  # @param insurance [Insurance] The insurance record
  # @return [Hash] Parser result with :status, :data, :raw keys
  def process_with_provider(insurance)
    Timeout.timeout(OCR_TIMEOUT) do
      if ocr_provider == :openai
        process_with_openai(insurance)
      else
        process_with_textract_and_fallback(insurance)
      end
    end
  end

  # Process with OpenAI Vision
  #
  # @param insurance [Insurance] The insurance record
  # @return [Hash] Parser result
  def process_with_openai(insurance)
    Rails.logger.info("OcrProcessingJob: Using OpenAI Vision for OCR")
    parser = ::InsuranceServices::OpenaiCardParser.new(insurance)
    result = parser.call
    result[:raw][:provider] = "openai"
    result
  end

  # Process with Textract, falling back to OpenAI on network errors
  #
  # @param insurance [Insurance] The insurance record
  # @return [Hash] Parser result
  def process_with_textract_and_fallback(insurance)
    Rails.logger.info("OcrProcessingJob: Using AWS Textract for OCR")
    parser = ::InsuranceServices::CardParser.new(insurance)
    result = parser.call
    result[:raw][:provider] = "textract"
    result
  rescue Seahorse::Client::NetworkingError => e
    # Fallback to OpenAI on network errors (common in local dev)
    if openai_available?
      Rails.logger.warn("OcrProcessingJob: Textract network error, falling back to OpenAI: #{e.message}")
      process_with_openai(insurance)
    else
      raise
    end
  end

  # Check if OpenAI is available as a fallback
  #
  # @return [Boolean]
  def openai_available?
    ENV["OPENAI_API_KEY"].present?
  end

  # Update insurance record with OCR extraction results
  #
  # @param insurance [Insurance] The insurance record
  # @param result [Hash] Parser result with :status, :data, :raw keys
  def update_insurance_with_results(insurance, result)
    data = result[:data]

    # Merge OCR data into verification_result
    verification_result = (insurance.verification_result || {}).merge(
      "ocr_raw" => result[:raw],
      "ocr_extracted" => data[:extracted_fields],
      "ocr_confidence" => data[:confidence_scores],
      "ocr_low_confidence_fields" => data[:low_confidence_fields],
      "ocr_completed_at" => Time.current.iso8601
    )

    # Build update attributes
    update_attrs = {
      verification_status: result[:status],
      verification_result: verification_result
    }

    # Apply high-confidence extracted fields to insurance record
    high_confidence_fields(data).each do |field, value|
      update_attrs[field] = value
    end

    insurance.update!(update_attrs)
  end

  # Get fields with high enough confidence to auto-populate
  #
  # @param data [Hash] Extracted data with :extracted_fields and :confidence_scores
  # @return [Hash] Fields with confidence >= 85%
  def high_confidence_fields(data)
    fields = {}

    data[:extracted_fields].each do |field, value|
      confidence = data[:confidence_scores][field]
      if confidence && confidence >= 85.0 && value.present?
        # For payer_name, do case-insensitive matching and use canonical name
        if field == :payer_name
          canonical_name = find_matching_payer_name(value)
          if canonical_name.nil?
            Rails.logger.info("OcrProcessingJob: Skipping payer_name '#{value}' - not in known payers list")
            next
          end
          fields[field] = canonical_name
        else
          fields[field] = value
        end
      end
    end

    fields
  end

  # Find matching payer name with case-insensitive comparison
  #
  # @param ocr_value [String] The OCR-extracted payer name
  # @return [String, nil] The canonical payer name if found, nil otherwise
  def find_matching_payer_name(ocr_value)
    return nil if ocr_value.blank?

    normalized_value = ocr_value.downcase.strip
    Insurance.known_payer_names.find do |known_name|
      known_name.downcase == normalized_value
    end
  end

  # Trigger GraphQL subscription for OCR completion
  #
  # @param insurance [Insurance] The updated insurance record
  def trigger_status_subscription(insurance)
    # Format session_id to match frontend subscription format (sess_ prefix)
    formatted_session_id = format_session_id(insurance.onboarding_session_id)
    DaybreakHealthBackendSchema.subscriptions.trigger(
      :insurance_status_changed,
      { session_id: formatted_session_id },
      insurance
    )
  rescue StandardError => e
    # Don't fail the job if subscription trigger fails
    Rails.logger.error("OcrProcessingJob: Failed to trigger subscription - #{e.message}")
  end

  # Create audit log entry for OCR processing
  #
  # @param insurance [Insurance] The insurance record
  # @param result [Hash] Parser result
  def create_audit_log(insurance, result)
    # Use Auditable concern if available, otherwise direct AuditLog creation
    details = {
      status: result[:status].to_s,
      fields_extracted: result[:data][:extracted_fields].keys,
      needs_review: result[:data][:needs_review],
      confidence_summary: summarize_confidence(result[:data][:confidence_scores])
    }

    if defined?(AuditLog)
      AuditLog.create!(
        action: "OCR_PROCESSING_COMPLETED",
        resource: "Insurance",
        resource_id: insurance.id,
        onboarding_session_id: insurance.onboarding_session_id,
        details: details
      )
    else
      Rails.logger.info("OcrProcessingJob: Audit - #{details.to_json}")
    end
  rescue StandardError => e
    # Don't fail the job if audit log creation fails
    Rails.logger.error("OcrProcessingJob: Failed to create audit log - #{e.message}")
  end

  # Summarize confidence scores for audit log (no PHI)
  #
  # @param confidence_scores [Hash] Field => confidence mappings
  # @return [Hash] Summary with min/max/avg confidence
  def summarize_confidence(confidence_scores)
    return {} if confidence_scores.blank?

    values = confidence_scores.values.compact
    return {} if values.empty?

    {
      min: values.min.round(1),
      max: values.max.round(1),
      avg: (values.sum / values.size).round(1),
      fields_count: values.size
    }
  end

  # Handle OCR processing timeout
  #
  # @param insurance [Insurance] The insurance record
  def handle_timeout(insurance)
    Rails.logger.error("OcrProcessingJob: Timeout for insurance #{insurance.id}")
    record_failure(insurance, "TIMEOUT", "OCR processing timed out after #{OCR_TIMEOUT} seconds")
  end

  # Handle Textract API errors
  #
  # @param insurance [Insurance] The insurance record
  # @param error [Aws::Textract::Errors::ServiceError] The Textract error
  def handle_textract_error(insurance, error)
    error_code = error.class.name.demodulize
    Rails.logger.error("OcrProcessingJob: Textract error for insurance #{insurance.id} - #{error_code}: #{error.message}")
    record_failure(insurance, error_code, error.message)
  end

  # Record failure in insurance verification_result
  #
  # @param insurance [Insurance] The insurance record
  # @param code [String] Error code
  # @param message [String] Error message
  def record_failure(insurance, code, message)
    verification_result = (insurance.verification_result || {}).merge(
      "error" => {
        "code" => code,
        "message" => message,
        "occurred_at" => Time.current.iso8601
      }
    )

    insurance.update!(
      verification_status: :failed,
      verification_result: verification_result
    )

    # Trigger subscription for failure notification
    trigger_status_subscription(insurance)

    # Audit log for failure
    if defined?(AuditLog)
      AuditLog.create!(
        action: "OCR_PROCESSING_FAILED",
        resource: "Insurance",
        resource_id: insurance.id,
        onboarding_session_id: insurance.onboarding_session_id,
        details: { error_code: code }
      )
    end
  rescue StandardError => e
    Rails.logger.error("OcrProcessingJob: Failed to record failure - #{e.message}")
  end

  # Class method to handle permanent failures from discard_on/retry_on callbacks
  # These run in class context, so we need a class method
  def self.handle_permanent_failure(insurance_id, code, message)
    Rails.logger.error("OcrProcessingJob: Permanent failure for insurance #{insurance_id} - #{code}: #{message}")

    insurance = Insurance.find_by(id: insurance_id)
    return unless insurance

    verification_result = (insurance.verification_result || {}).merge(
      "error" => {
        "code" => code,
        "message" => message,
        "occurred_at" => Time.current.iso8601
      }
    )

    insurance.update!(
      verification_status: :failed,
      verification_result: verification_result
    )

    # Trigger subscription for failure notification
    formatted_session_id = GraphqlConcerns::SessionIdParser.format_session_id(insurance.onboarding_session_id)
    DaybreakHealthBackendSchema.subscriptions.trigger(
      :insurance_status_changed,
      { session_id: formatted_session_id },
      insurance
    )

    # Audit log for failure
    if defined?(AuditLog)
      AuditLog.create!(
        action: "OCR_PROCESSING_FAILED",
        resource: "Insurance",
        resource_id: insurance.id,
        onboarding_session_id: insurance.onboarding_session_id,
        details: { error_code: code }
      )
    end
  rescue StandardError => e
    Rails.logger.error("OcrProcessingJob.handle_permanent_failure: #{e.message}")
  end
end
