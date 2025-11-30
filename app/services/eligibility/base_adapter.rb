# frozen_string_literal: true

module Eligibility
  # Base adapter class for insurance eligibility verification
  #
  # This class defines the interface that all payer-specific adapters must implement.
  # It provides common helper methods for building verification results and handling errors.
  #
  # @abstract Subclass and override {#verify_eligibility} to implement payer-specific logic
  #
  # @example Creating a payer-specific adapter
  #   class AetnaAdapter < BaseAdapter
  #     def verify_eligibility(insurance)
  #       # Aetna-specific API integration
  #     end
  #   end
  #
  # @see Eligibility::EdiAdapter
  # @see Eligibility::AdapterFactory
  class BaseAdapter
    # Timeout threshold for verification requests (30 seconds per AC8)
    TIMEOUT_SECONDS = 30

    # Error categories for categorizing verification failures (AC7)
    ERROR_CATEGORIES = {
      invalid_member_id: "invalid_member_id",
      coverage_not_active: "coverage_not_active",
      service_not_covered: "service_not_covered",
      network_error: "network_error",
      timeout: "timeout",
      unknown: "unknown"
    }.freeze

    # Perform eligibility verification for the given insurance record
    #
    # @param insurance [Insurance] The insurance record to verify
    # @return [Hash] Verification result with status, coverage, and error details
    # @raise [NotImplementedError] Subclasses must implement this method
    def verify_eligibility(insurance)
      raise NotImplementedError, "Subclass must implement verify_eligibility"
    end

    protected

    # Build a standardized verification result hash
    #
    # @param eligible [Boolean, nil] Whether coverage is active
    # @param coverage [Hash] Coverage details (copay, deductible, coinsurance, etc.)
    # @param error [Hash, nil] Error details if verification failed
    # @return [Hash] Standardized verification result
    def build_verification_result(eligible:, coverage:, error: nil)
      {
        "status" => determine_status(eligible, error),
        "eligible" => eligible,
        "coverage" => coverage.deep_stringify_keys,
        "error" => error&.deep_stringify_keys,
        "verified_at" => Time.current.iso8601,
        "api_response_id" => generate_response_id
      }
    end

    # Determine verification status based on eligibility and error
    #
    # @param eligible [Boolean, nil] Whether coverage is active
    # @param error [Hash, nil] Error details if any
    # @return [String] Status: VERIFIED, FAILED, or MANUAL_REVIEW
    def determine_status(eligible, error)
      if error.present?
        # Retryable errors with unclear eligibility -> manual review
        return "MANUAL_REVIEW" if error[:retryable] && eligible.nil?

        return "FAILED"
      end

      return "MANUAL_REVIEW" if eligible.nil?

      eligible ? "VERIFIED" : "FAILED"
    end

    # Generate a unique API response ID for tracking
    #
    # @return [String] UUID for tracking purposes
    def generate_response_id
      "eligibility-#{SecureRandom.uuid}"
    end

    # Build a timeout error hash
    #
    # @return [Hash] Timeout error with retryable flag
    def timeout_error
      {
        code: "TIMEOUT",
        category: ERROR_CATEGORIES[:timeout],
        message: "Verification timed out after #{TIMEOUT_SECONDS} seconds",
        retryable: true
      }
    end

    # Build a network error hash
    #
    # @param exception [Exception] The network exception that occurred
    # @return [Hash] Network error with retryable flag
    def network_error(exception)
      {
        code: "NETWORK_ERROR",
        category: ERROR_CATEGORIES[:network_error],
        message: "Network error: #{exception.message}",
        retryable: true
      }
    end

    # Build a coverage structure with default values
    #
    # @param mental_health_covered [Boolean] Whether mental health is covered
    # @param copay [Hash, nil] Copay amount details
    # @param deductible [Hash, nil] Deductible details
    # @param coinsurance [Hash, nil] Coinsurance percentage
    # @param effective_date [String, nil] Coverage effective date
    # @param termination_date [String, nil] Coverage termination date
    # @return [Hash] Standardized coverage structure
    def build_coverage(
      mental_health_covered:,
      copay: nil,
      deductible: nil,
      coinsurance: nil,
      effective_date: nil,
      termination_date: nil
    )
      {
        mental_health_covered: mental_health_covered,
        copay: copay,
        deductible: deductible,
        coinsurance: coinsurance,
        effective_date: effective_date,
        termination_date: termination_date
      }.compact
    end

    # Build a copay structure
    #
    # @param amount [Numeric] Copay amount in dollars
    # @param currency [String] Currency code (default: USD)
    # @return [Hash] Copay structure
    def build_copay(amount:, currency: "USD")
      {
        amount: amount.to_f.round(2),
        currency: currency
      }
    end

    # Build a deductible structure
    #
    # @param amount [Numeric] Deductible amount in dollars
    # @param met [Numeric] Amount already met
    # @param currency [String] Currency code (default: USD)
    # @return [Hash] Deductible structure
    def build_deductible(amount:, met: 0, currency: "USD")
      {
        amount: amount.to_f.round(2),
        met: met.to_f.round(2),
        currency: currency
      }
    end

    # Build a coinsurance structure
    #
    # @param percentage [Numeric] Coinsurance percentage (0-100)
    # @return [Hash] Coinsurance structure
    def build_coinsurance(percentage:)
      {
        percentage: percentage.to_i
      }
    end

    # Map a category to its error hash
    #
    # @param category [Symbol] Error category
    # @param message [String] Error message
    # @param retryable [Boolean] Whether the error is retryable
    # @return [Hash] Standardized error hash
    def build_error(category:, message:, retryable: false, code: nil)
      {
        code: code || category.to_s.upcase,
        category: ERROR_CATEGORIES[category] || ERROR_CATEGORIES[:unknown],
        message: message,
        retryable: retryable
      }
    end
  end
end
