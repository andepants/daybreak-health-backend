# frozen_string_literal: true

module InsuranceServices
  # Generates user-friendly status messages and next steps for insurance verification
  #
  # Converts technical verification statuses and error codes into plain language
  # that parents can understand. Provides contextual next steps based on the
  # specific error or status encountered.
  #
  # @example
  #   service = Insurance::StatusMessageService.new(insurance)
  #   display = service.generate_display
  #   # => { status_display: "Needs Attention", message: "...", ... }
  #
  class StatusMessageService
    # Maximum number of retry attempts allowed
    MAX_RETRY_ATTEMPTS = 3

    # Error codes with user-friendly messages and severity levels
    # Severity levels:
    #   :low - Temporary issues, can retry immediately
    #   :medium - Data issues, need correction before retry
    #   :high - Non-recoverable issues, need alternative path
    ERROR_MESSAGES = {
      "INVALID_MEMBER_ID" => {
        message: "We couldn't find this member ID with your insurance company.",
        severity: :medium,
        why: "The member ID you entered doesn't match records at your insurance company. This could be a typo or the ID may have changed."
      },
      "INVALID_GROUP_NUMBER" => {
        message: "The group number doesn't match your insurance records.",
        severity: :medium,
        why: "The group number entered doesn't match your insurance company's records. Double-check your insurance card."
      },
      "SUBSCRIBER_NOT_FOUND" => {
        message: "We couldn't find the subscriber information.",
        severity: :medium,
        why: "The subscriber name or date of birth doesn't match records. Ensure you're using the policyholder's information."
      },
      "COVERAGE_INACTIVE" => {
        message: "Your coverage isn't currently active.",
        severity: :high,
        why: "Your insurance plan shows as inactive. This could mean premiums weren't paid or the plan has ended."
      },
      "COVERAGE_TERMINATED" => {
        message: "Your coverage has ended.",
        severity: :high,
        why: "Your insurance plan has been terminated. You may need to contact your insurance company or employer."
      },
      "SERVICE_NOT_COVERED" => {
        message: "Mental health services aren't covered under this plan.",
        severity: :high,
        why: "Your plan doesn't include coverage for the mental health services we provide."
      },
      "OUT_OF_NETWORK" => {
        message: "We're not in your insurance network.",
        severity: :high,
        why: "Daybreak Health is not in your insurance plan's network. Out-of-network coverage may be limited or unavailable."
      },
      "PAYER_NOT_SUPPORTED" => {
        message: "We don't currently work with this insurance company.",
        severity: :high,
        why: "We haven't established a partnership with this insurance company yet."
      },
      "NETWORK_ERROR" => {
        message: "We're having trouble connecting to your insurance company.",
        severity: :low,
        why: "There's a temporary connection issue. This usually resolves quickly."
      },
      "TIMEOUT" => {
        message: "The verification is taking longer than expected.",
        severity: :low,
        why: "Your insurance company's system is responding slowly. You can try again in a few minutes."
      },
      "SERVICE_UNAVAILABLE" => {
        message: "Your insurance company's system is temporarily unavailable.",
        severity: :low,
        why: "Their system is down for maintenance or experiencing issues. Please try again later."
      },
      "RATE_LIMITED" => {
        message: "Too many requests. Please wait a moment.",
        severity: :low,
        why: "We've made too many requests in a short time. Please wait a minute before trying again."
      }
    }.freeze

    # Maps verification status to user-friendly display text
    STATUS_DISPLAY_MAP = {
      "verified" => "Verified",
      "pending" => "Checking...",
      "in_progress" => "Checking...",
      "ocr_complete" => "Ready for Verification",
      "ocr_needs_review" => "Needs Attention",
      "manual_entry" => "Awaiting Information",
      "manual_entry_complete" => "Ready for Verification",
      "manual_review" => "Needs Attention",
      "self_pay" => "Self-Pay Selected"
      # 'failed' is determined dynamically by error severity
    }.freeze

    # @param insurance [Insurance] The insurance record to generate messages for
    def initialize(insurance)
      @insurance = insurance
      @result = insurance.verification_result || {}
    end

    # Generates the complete display data for the insurance status
    #
    # @return [Hash] Display data including status, message, next steps, etc.
    def generate_display
      {
        status_display: status_display_text,
        message: plain_language_message,
        why_explanation: why_explanation,
        next_steps: generate_next_steps,
        can_retry: can_retry?,
        support_contact: support_contact,
        self_pay_option: self_pay_option
      }
    end

    # Get the user-friendly status display text
    #
    # @return [String] Status text like "Verified", "Needs Attention", etc.
    def status_display_text
      return "Verified" if @insurance.verified?
      return "Self-Pay Selected" if @insurance.self_pay?

      if @insurance.failed?
        error_severity == :high ? "Unable to Verify" : "Needs Attention"
      else
        STATUS_DISPLAY_MAP[@insurance.verification_status] || "Needs Attention"
      end
    end

    # Get the plain language message explaining the status
    #
    # @return [String] User-friendly message
    def plain_language_message
      return "Your insurance is verified and active!" if @insurance.verified?
      return "You've chosen to pay out of pocket. No insurance will be billed." if @insurance.self_pay?

      error_info[:message]
    end

    # Get the detailed "why" explanation
    #
    # @return [String] Detailed explanation of why this status occurred
    def why_explanation
      return nil if @insurance.verified? || @insurance.self_pay?

      error_info[:why]
    end

    # Check if verification can be retried
    #
    # @return [Boolean] True if retry is allowed
    def can_retry?
      return false if @insurance.verified?
      return false if @insurance.self_pay?
      return false if @insurance.retry_attempts >= MAX_RETRY_ATTEMPTS

      error = @result.dig("error") || {}

      # If explicitly marked as not retryable, respect that
      return false if error["retryable"] == false

      # High severity errors should not be retried
      return false if error_severity == :high

      true
    end

    # Generate contextual next steps based on status
    #
    # @return [Array<String>] Array of action items
    def generate_next_steps
      if @insurance.verified?
        [
          "Continue to your child's assessment",
          "Review your coverage details below"
        ]
      elsif @insurance.self_pay?
        [
          "Continue to your child's assessment",
          "Review self-pay rates and payment options"
        ]
      elsif can_retry?
        generate_retry_next_steps
      else
        generate_non_retry_next_steps
      end
    end

    # Get appropriate support contact based on error severity
    #
    # @return [Hash] Support contact information
    def support_contact
      config = Rails.application.config.insurance_support_contacts rescue nil
      config ||= default_support_contacts

      if error_severity == :high || @insurance.retry_attempts >= MAX_RETRY_ATTEMPTS
        config[:specialist]
      else
        config[:general]
      end
    end

    # Get self-pay option (always available)
    #
    # @return [Hash] Self-pay option details
    def self_pay_option
      config = Rails.application.config.self_pay_options rescue nil
      config ||= default_self_pay_option

      {
        available: true,
        description: config[:description] || "Continue with self-pay",
        preview_rate: config[:preview_rate] || "$150 for initial assessment"
      }
    end

    private

    # Get the error code from verification result
    #
    # @return [String, nil] Error code
    def error_code
      @result.dig("error", "code")
    end

    # Get error information for the current error code
    #
    # @return [Hash] Error info with message, severity, and why
    def error_info
      ERROR_MESSAGES[error_code] || {
        message: "We encountered an issue verifying your insurance.",
        severity: :medium,
        why: "An unexpected error occurred. Our team has been notified."
      }
    end

    # Get the severity level of the current error
    #
    # @return [Symbol] :low, :medium, or :high
    def error_severity
      return :low if @insurance.pending? || @insurance.in_progress?

      error_info[:severity]
    end

    # Generate next steps for retriable errors
    #
    # @return [Array<String>] Next steps for retry flow
    def generate_retry_next_steps
      steps = []

      case error_code
      when "INVALID_MEMBER_ID", "INVALID_GROUP_NUMBER", "SUBSCRIBER_NOT_FOUND"
        steps << "Double-check your insurance card"
        steps << "Correct any errors in your information"
        steps << "Try verification again"
      when "NETWORK_ERROR", "TIMEOUT", "SERVICE_UNAVAILABLE"
        steps << "Wait a moment and try again"
        steps << "If the issue persists, contact our support team"
      else
        steps << "Review your insurance information"
        steps << "Correct any errors"
        steps << "Try verification again"
      end

      steps << "Choose self-pay to continue immediately"
      steps
    end

    # Generate next steps for non-retriable errors
    #
    # @return [Array<String>] Next steps for non-retry situations
    def generate_non_retry_next_steps
      steps = []

      case error_code
      when "COVERAGE_INACTIVE", "COVERAGE_TERMINATED"
        steps << "Contact your insurance company to verify your coverage"
        steps << "If you have new insurance, enter the updated information"
      when "SERVICE_NOT_COVERED", "OUT_OF_NETWORK"
        steps << "Check if you have a different plan that covers mental health"
        steps << "Ask your insurance about out-of-network benefits"
      when "PAYER_NOT_SUPPORTED"
        steps << "Check if you have secondary insurance we can verify"
      else
        steps << "Contact your insurance company for assistance"
        steps << "Call our support team for help"
      end

      steps << "Choose self-pay to continue now"
      steps
    end

    # Default support contacts if config is not loaded
    #
    # @return [Hash] Default contact information
    def default_support_contacts
      {
        general: {
          type: "general",
          phone: "1-800-DAYBREAK",
          email: "support@daybreak.health",
          hours: "Mon-Sun 8am-8pm EST"
        },
        specialist: {
          type: "specialist",
          phone: "1-800-DAYBREAK x2",
          email: "insurance@daybreak.health",
          hours: "Mon-Fri 8am-6pm EST"
        }
      }
    end

    # Default self-pay option if config is not loaded
    #
    # @return [Hash] Default self-pay configuration
    def default_self_pay_option
      {
        description: "Continue with self-pay",
        preview_rate: "$150 for initial assessment"
      }
    end
  end
end
