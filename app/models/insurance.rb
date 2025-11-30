# frozen_string_literal: true

class Insurance < ApplicationRecord
  include Encryptable
  include Auditable

  # Enums - expanded for full verification workflow
  enum :verification_status, {
    pending: 0,                   # Card uploaded, awaiting OCR
    in_progress: 1,               # OCR processing
    ocr_complete: 2,              # OCR finished, awaiting review (Story 4.2)
    ocr_needs_review: 3,          # OCR needs manual review (Story 4.2)
    manual_entry: 4,              # Manual entry in progress (Story 4.3)
    verified: 5,                  # Eligibility verified
    failed: 6,                    # Verification failed
    manual_review: 7,             # Needs human review
    self_pay: 8,                  # Self-pay selected
    manual_entry_complete: 9      # Manual entry complete (Story 4.3)
  }

  # Associations
  belongs_to :onboarding_session

  # Scopes for OCR status filtering
  scope :ocr_pending, -> { where(verification_status: [:pending, :in_progress]) }
  scope :ocr_completed, -> { where(verification_status: [:ocr_complete, :ocr_needs_review]) }
  scope :needs_ocr_review, -> { where(verification_status: :ocr_needs_review) }

  # Active Storage attachments for insurance card images
  # Images are stored in S3 with SSE-KMS encryption
  has_one_attached :card_image_front
  has_one_attached :card_image_back

  # PHI Encryption - only text fields, not Active Storage attachments
  # Active Storage files are encrypted via S3 SSE-KMS
  encrypts_phi :subscriber_name, :policy_number, :group_number, :member_id, :subscriber_dob

  # Validations
  validates :onboarding_session, presence: true

  # Story 4.3: Manual entry validations (allow_blank for partial save support)
  validates :member_id, format: {
    with: /\A[A-Za-z0-9]{6,20}\z/,
    message: "must be 6-20 alphanumeric characters"
  }, allow_blank: true

  validates :group_number, format: {
    with: /\A[A-Za-z0-9]{4,15}\z/,
    message: "must be 4-15 alphanumeric characters"
  }, allow_blank: true

  validates :payer_name, inclusion: {
    in: ->(_) { Insurance.known_payer_names },
    message: "must be a known payer or 'Other'"
  }, allow_blank: true

  validate :subscriber_dob_not_in_future, if: :subscriber_dob_present?

  # Callbacks for image retention policy (AC10)
  after_update :purge_images_if_verification_complete, if: :verification_complete?

  # Generate presigned URL for front card image
  #
  # @param expires_in [ActiveSupport::Duration] URL expiry time (default: 15 minutes)
  # @return [String, nil] Presigned URL or nil if no attachment
  def front_image_url(expires_in: 15.minutes)
    return nil unless card_image_front.attached?

    card_image_front.url(expires_in: expires_in)
  end

  # Generate presigned URL for back card image
  #
  # @param expires_in [ActiveSupport::Duration] URL expiry time (default: 15 minutes)
  # @return [String, nil] Presigned URL or nil if no attachment
  def back_image_url(expires_in: 15.minutes)
    return nil unless card_image_back.attached?

    card_image_back.url(expires_in: expires_in)
  end

  # OCR Helper Methods (Story 4.2)

  # Get raw OCR data from verification_result
  #
  # @return [Hash, nil] Raw OCR response data
  def ocr_data
    verification_result&.dig("ocr_raw")
  end

  # Get extracted OCR fields
  #
  # @return [Hash, nil] Extracted field values
  def ocr_extracted
    verification_result&.dig("ocr_extracted")
  end

  # Get OCR confidence scores for each field
  #
  # @return [Hash, nil] Field => confidence score mappings
  def ocr_confidence
    verification_result&.dig("ocr_confidence")
  end

  # Get list of fields with low confidence scores
  #
  # @return [Array<String>] Field names that need review
  def ocr_low_confidence_fields
    verification_result&.dig("ocr_low_confidence_fields") || []
  end

  # Check if any OCR field needs manual review
  #
  # @return [Boolean] True if any field has low confidence
  def needs_ocr_review?
    ocr_needs_review? || ocr_low_confidence_fields.any?
  end

  # Get OCR completion timestamp
  #
  # @return [Time, nil] When OCR processing completed
  def ocr_completed_at
    timestamp = verification_result&.dig("ocr_completed_at")
    Time.parse(timestamp) if timestamp.present?
  end

  # Check if OCR has been processed
  #
  # @return [Boolean] True if OCR processing has completed
  def ocr_processed?
    ocr_complete? || ocr_needs_review?
  end

  # Get OCR error if processing failed
  #
  # @return [Hash, nil] Error details with :code and :message
  def ocr_error
    verification_result&.dig("error")
  end

  # Story 4.3: Manual Entry Helper Methods

  # Load known payer names from configuration
  #
  # @return [Array<String>] List of known payer names
  def self.known_payer_names
    Rails.application.config.known_payer_names || []
  rescue StandardError
    # Fallback for tests or when config is not loaded
    payers_file = Rails.root.join("config/known_payers.yml")
    return [] unless File.exist?(payers_file)

    YAML.load_file(payers_file)["payers"].map { |p| p["name"] }
  end

  # Check if OCR data is available for pre-population
  #
  # @return [Boolean] True if OCR extracted data exists
  def ocr_data_available?
    verification_result&.dig("ocr_extracted").present?
  end

  # Pre-populate fields from OCR data
  #
  # @return [Hash] Hash of field values from OCR
  def pre_populate_from_ocr
    return {} unless ocr_data_available?

    ocr = verification_result["ocr_extracted"]
    {
      payer_name: ocr["payer_name"],
      member_id: ocr["member_id"],
      group_number: ocr["group_number"],
      subscriber_name: ocr["subscriber_name"]
    }.compact
  end


  # Story 4.4: Eligibility Verification Helper Methods

  # Check if eligibility is verified (AC5)
  #
  # @return [Boolean] True if verification status is verified
  def eligibility_verified?
    verification_status == "verified"
  end

  # Check if eligibility verification failed (AC5)
  #
  # @return [Boolean] True if verification status is failed
  def eligibility_failed?
    verification_status == "failed"
  end

  # Check if eligibility needs manual review (AC5)
  #
  # @return [Boolean] True if verification status is manual_review
  def needs_eligibility_review?
    verification_status == "manual_review"
  end

  # Check if member is eligible for coverage (AC3)
  #
  # @return [Boolean, nil] True if eligible, false if not, nil if unclear
  def eligible?
    verification_result&.dig("eligible")
  end

  # Check if mental health services are covered (AC4)
  #
  # @return [Boolean] True if mental health is specifically covered
  def mental_health_covered?
    verification_result&.dig("coverage", "mental_health_covered") == true
  end

  # Get copay amount for mental health services (AC3)
  #
  # @return [Float, nil] Copay amount in dollars
  def copay_amount
    verification_result&.dig("coverage", "copay", "amount")
  end

  # Get deductible amount (AC3)
  #
  # @return [Float, nil] Deductible amount in dollars
  def deductible_amount
    verification_result&.dig("coverage", "deductible", "amount")
  end

  # Get deductible amount already met (AC3)
  #
  # @return [Float, nil] Amount met in dollars
  def deductible_met
    verification_result&.dig("coverage", "deductible", "met")
  end

  # Get coinsurance percentage (AC3)
  #
  # @return [Integer, nil] Coinsurance percentage (0-100)
  def coinsurance_percentage
    verification_result&.dig("coverage", "coinsurance", "percentage")
  end

  # Get coverage effective date
  #
  # @return [Date, nil] Coverage effective date
  def coverage_effective_date
    date_str = verification_result&.dig("coverage", "effective_date")
    Date.parse(date_str) if date_str.present?
  rescue Date::Error
    nil
  end

  # Get coverage termination date
  #
  # @return [Date, nil] Coverage termination date
  def coverage_termination_date
    date_str = verification_result&.dig("coverage", "termination_date")
    Date.parse(date_str) if date_str.present?
  rescue Date::Error
    nil
  end

  # Get verification error category (AC7)
  #
  # @return [String, nil] Error category (invalid_member_id, coverage_not_active, etc.)
  def error_category
    verification_result&.dig("error", "category")
  end

  # Get verification error message
  #
  # @return [String, nil] Human-readable error message
  def error_message
    verification_result&.dig("error", "message")
  end

  # Check if verification can be retried (AC7)
  # Story 4.5: Enhanced retry logic with attempt tracking
  #
  # @return [Boolean] True if error is retryable
  def can_retry_verification?
    return false if eligibility_verified?
    return false if self_pay?
    return false if retry_attempts >= max_retry_attempts

    error = verification_result&.dig("error")
    return true unless error

    # If explicitly marked as not retryable, respect that
    return false if error["retryable"] == false

    # High severity errors should not be retried
    severity = error_severity_level
    return false if severity == :high

    true
  end

  # Story 4.5: Increment retry attempt counter
  #
  # @return [Integer] The new retry count
  def increment_retry_attempts!
    increment!(:retry_attempts)
    record_retry_history
    retry_attempts
  end

  # Story 4.5: Get error severity level
  #
  # @return [Symbol] :low, :medium, or :high
  def error_severity_level
    error = verification_result&.dig("error")
    return :low if pending? || in_progress?
    return :medium unless error

    error_code = error["code"]
    high_severity_codes = %w[
      COVERAGE_INACTIVE COVERAGE_TERMINATED SERVICE_NOT_COVERED
      OUT_OF_NETWORK PAYER_NOT_SUPPORTED
    ]
    low_severity_codes = %w[
      NETWORK_ERROR TIMEOUT SERVICE_UNAVAILABLE RATE_LIMITED
    ]

    if high_severity_codes.include?(error_code)
      :high
    elsif low_severity_codes.include?(error_code)
      :low
    else
      :medium
    end
  end

  # Story 4.5: Maximum retry attempts allowed
  #
  # @return [Integer] Maximum retry attempts
  def max_retry_attempts
    3
  end

  # Story 4.5: Record retry in history
  #
  # @return [void]
  def record_retry_history
    result = verification_result || {}
    history = result["retry_history"] || []
    history << {
      attempt: retry_attempts,
      timestamp: Time.current.iso8601,
      previous_error: result.dig("error", "code")
    }
    result["retry_history"] = history
    update_column(:verification_result, result)
  end

  # Check if cached result is still valid (AC6 - 24 hours)
  #
  # @return [Boolean] True if verified_at is within 24 hours
  def cached_result_valid?
    return false unless verification_result.present?

    verified_at_str = verification_result["verified_at"]
    return false unless verified_at_str

    verified_at = Time.zone.parse(verified_at_str)
    verified_at > 24.hours.ago
  rescue ArgumentError
    false
  end

  # Get when eligibility was verified
  #
  # @return [Time, nil] Verification timestamp
  def verified_at
    timestamp = verification_result&.dig("verified_at")
    Time.zone.parse(timestamp) if timestamp.present?
  rescue ArgumentError
    nil
  end

  # Get API response reference ID for support debugging
  #
  # @return [String, nil] API response ID
  def eligibility_response_id
    verification_result&.dig("api_response_id")
  end

  # Scopes for eligibility status filtering
  scope :pending_eligibility, -> { where(verification_status: [:pending, :in_progress]) }
  scope :eligibility_verified, -> { where(verification_status: :verified) }
  scope :eligibility_failed, -> { where(verification_status: :failed) }
  scope :needs_eligibility_review, -> { where(verification_status: :manual_review) }

  private

  def verification_complete?
    saved_change_to_verification_status? &&
      (verified? || self_pay?)
  end

  def purge_images_if_verification_complete
    purge_card_images
  end

  def purge_card_images
    card_image_front.purge_later if card_image_front.attached?
    card_image_back.purge_later if card_image_back.attached?

    # Log image purge for audit trail
    Rails.logger.info("Insurance #{id}: Card images purged after verification complete")
  end

  # Story 4.3: Subscriber DOB validation helpers

  def subscriber_dob_present?
    subscriber_dob.present?
  end

  def subscriber_dob_not_in_future
    return unless subscriber_dob.present?

    begin
      dob = Date.parse(subscriber_dob)
      errors.add(:subscriber_dob, "cannot be in the future") if dob > Date.current
    rescue Date::Error, ArgumentError
      errors.add(:subscriber_dob, "must be a valid date")
    end
  end
end
