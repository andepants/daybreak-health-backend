# frozen_string_literal: true

# Background job for insurance eligibility verification
#
# This job performs async eligibility verification by calling external
# eligibility APIs via the adapter pattern. Progress updates are sent
# via GraphQL subscriptions for real-time UI feedback.
#
# @example Enqueue job
#   EligibilityVerificationJob.perform_later(insurance_id)
#
# @see Eligibility::AdapterFactory
# @see Subscriptions::InsuranceStatusChanged
class EligibilityVerificationJob < ApplicationJob
  include GraphqlConcerns::SessionIdParser

  # Use the insurance queue configured in sidekiq.yml
  queue_as :insurance

  # Retry configuration - 3 attempts with exponential backoff (AC8)
  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
    handle_max_retries_exceeded(job.arguments.first, error)
  end

  # Discard jobs for missing records
  discard_on ActiveRecord::RecordNotFound

  # Cache TTL for verification results (24 hours per AC6)
  CACHE_TTL = 24.hours

  # Job timeout (35 seconds: 30s API + 5s processing)
  JOB_TIMEOUT = 35.seconds

  # Progress stages for real-time updates
  PROGRESS_STAGES = {
    started: { percentage: 0, message: "Contacting insurance company..." },
    api_called: { percentage: 33, message: "Checking coverage..." },
    parsing: { percentage: 66, message: "Processing response..." },
    complete: { percentage: 100, message: "Verification complete" }
  }.freeze

  # Perform eligibility verification
  #
  # @param insurance_id [String] The insurance record ID
  def perform(insurance_id)
    insurance = ::Insurance.includes(:onboarding_session).find(insurance_id)

    # Emit progress: started
    emit_progress(insurance, :started)

    # Get appropriate adapter for payer
    adapter = ::Eligibility::AdapterFactory.adapter_for(insurance)

    # Emit progress: API called
    emit_progress(insurance, :api_called)

    # Verify eligibility (with timeout handling in adapter)
    result = adapter.verify_eligibility(insurance)

    # Emit progress: parsing
    emit_progress(insurance, :parsing)

    # Update insurance record with results
    update_insurance(insurance, result)

    # Cache result for 24 hours
    cache_result(insurance, result)

    # Emit progress: complete
    emit_progress(insurance, :complete)

    # Trigger subscription for final result
    trigger_subscription(insurance)

    # Create audit log
    create_audit_log(insurance, result)
  rescue StandardError => e
    # Handle job failure
    Rails.logger.error("Eligibility verification failed for insurance #{insurance_id}: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))

    handle_job_failure(insurance_id, e)

    # Re-raise for Sidekiq retry
    raise
  end

  private

  # Update insurance record with verification result
  #
  # @param insurance [Insurance] The insurance record
  # @param result [Hash] Verification result
  def update_insurance(insurance, result)
    status = map_status(result["status"])

    insurance.update!(
      verification_result: result,
      verification_status: status
    )
  end

  # Map result status to enum value
  #
  # @param status [String] Status from verification result
  # @return [Symbol] Insurance verification_status enum value
  def map_status(status)
    case status&.upcase
    when "VERIFIED"
      :verified
    when "FAILED"
      :failed
    when "MANUAL_REVIEW"
      :manual_review
    else
      :failed
    end
  end

  # Cache verification result in Redis
  #
  # @param insurance [Insurance] The insurance record
  # @param result [Hash] Verification result
  def cache_result(insurance, result)
    cache_key = "insurance:eligibility:#{insurance.id}"
    Rails.cache.write(cache_key, result, expires_in: CACHE_TTL)

    Rails.logger.info("Cached eligibility result for insurance #{insurance.id}")
  end

  # Emit progress update via subscription
  #
  # @param insurance [Insurance] The insurance record
  # @param stage [Symbol] Progress stage (:started, :api_called, :parsing, :complete)
  def emit_progress(insurance, stage)
    progress = PROGRESS_STAGES[stage]
    return unless progress

    formatted_session_id = format_session_id(insurance.onboarding_session_id)
    DaybreakHealthBackendSchema.subscriptions.trigger(
      :insurance_status_changed,
      { session_id: formatted_session_id },
      {
        insurance: insurance,
        progress: {
          percentage: progress[:percentage],
          message: progress[:message]
        }
      }
    )
  rescue StandardError => e
    # Don't fail the job if subscription trigger fails
    Rails.logger.warn("Failed to emit progress for insurance #{insurance.id}: #{e.message}")
  end

  # Trigger final subscription update
  #
  # @param insurance [Insurance] The insurance record
  def trigger_subscription(insurance)
    formatted_session_id = format_session_id(insurance.onboarding_session_id)
    DaybreakHealthBackendSchema.subscriptions.trigger(
      :insurance_status_changed,
      { session_id: formatted_session_id },
      { insurance: insurance.reload }
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to trigger subscription for insurance #{insurance.id}: #{e.message}")
  end

  # Create audit log entry for verification result
  #
  # @param insurance [Insurance] The insurance record
  # @param result [Hash] Verification result
  def create_audit_log(insurance, result)
    action = case result["status"]
             when "VERIFIED"
               "ELIGIBILITY_VERIFICATION_COMPLETED"
             when "MANUAL_REVIEW"
               "ELIGIBILITY_VERIFICATION_MANUAL_REVIEW"
             else
               "ELIGIBILITY_VERIFICATION_FAILED"
             end

    AuditLog.create!(
      onboarding_session_id: insurance.onboarding_session_id,
      action: action,
      resource: "Insurance",
      resource_id: insurance.id,
      details: {
        status: result["status"],
        eligible: result["eligible"],
        error_category: result.dig("error", "category"),
        api_response_id: result["api_response_id"],
        timestamp: Time.current.iso8601
      }
    )
  rescue StandardError => e
    Rails.logger.error("Failed to create audit log: #{e.message}")
  end

  # Handle job failure
  #
  # @param insurance_id [String] The insurance record ID
  # @param error [Exception] The error that occurred
  def handle_job_failure(insurance_id, error)
    insurance = ::Insurance.find_by(id: insurance_id)
    return unless insurance

    # Update insurance with failure status
    insurance.update!(
      verification_status: :failed,
      verification_result: {
        "status" => "FAILED",
        "eligible" => false,
        "coverage" => {},
        "error" => {
          "code" => "JOB_FAILED",
          "category" => "unknown",
          "message" => "Verification processing error",
          "retryable" => true
        },
        "verified_at" => Time.current.iso8601
      }
    )

    # Trigger subscription with failure
    trigger_subscription(insurance)
  rescue StandardError => e
    Rails.logger.error("Failed to handle job failure: #{e.message}")
  end

  # Handle max retries exceeded - set to manual review (AC8)
  #
  # @param insurance_id [String] The insurance record ID
  # @param error [Exception] The final error
  def self.handle_max_retries_exceeded(insurance_id, error)
    Rails.logger.error("Eligibility verification max retries exceeded for insurance #{insurance_id}: #{error.message}")

    insurance = ::Insurance.find_by(id: insurance_id)
    return unless insurance

    # After 3 failed retries, set status to manual_review (AC8)
    insurance.update!(
      verification_status: :manual_review,
      verification_result: {
        "status" => "MANUAL_REVIEW",
        "eligible" => nil,
        "coverage" => {},
        "error" => {
          "code" => "MAX_RETRIES_EXCEEDED",
          "category" => "unknown",
          "message" => "Verification failed after multiple attempts - requires manual review",
          "retryable" => false
        },
        "verified_at" => Time.current.iso8601,
        "retry_count" => 3
      }
    )

    # Create audit log for manual review escalation
    AuditLog.create!(
      onboarding_session_id: insurance.onboarding_session_id,
      action: "ELIGIBILITY_VERIFICATION_ESCALATED",
      resource: "Insurance",
      resource_id: insurance.id,
      details: {
        reason: "max_retries_exceeded",
        error_message: error.message,
        timestamp: Time.current.iso8601
      }
    )

    # Trigger subscription with manual review status
    formatted_session_id = GraphqlConcerns::SessionIdParser.format_session_id(insurance.onboarding_session_id)
    DaybreakHealthBackendSchema.subscriptions.trigger(
      :insurance_status_changed,
      { session_id: formatted_session_id },
      { insurance: insurance.reload }
    )
  rescue StandardError => e
    Rails.logger.error("Failed to handle max retries exceeded: #{e.message}")
  end
end
