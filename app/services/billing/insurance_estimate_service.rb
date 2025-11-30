# frozen_string_literal: true

module Billing
  # Service for calculating estimated costs based on insurance coverage
  #
  # Calculates patient responsibility and insurance payment estimates based on:
  # - Coverage details from eligibility verification (copay, coinsurance, deductible)
  # - Deductible status (met, partially met, not met)
  # - Plan type (HMO, PPO, high-deductible)
  # - Network status (in-network vs out-of-network)
  #
  # Returns structured estimate with:
  # - insurance_pays: Amount insurance will cover
  # - patient_pays: Patient's out-of-pocket responsibility
  # - allowed_amount: Contracted rate for the service
  # - billed_amount: Provider's standard rate
  # - deductible_status: Current deductible information
  # - coverage_limitations: Array of limitation messages
  # - is_estimate: Always true (not a guarantee)
  # - disclaimer: Standard estimate disclaimer text
  #
  # Example usage:
  #   result = Billing::InsuranceEstimateService.call(
  #     insurance: insurance_record,
  #     service_type: 'individual_therapy'
  #   )
  #   # => { insurance_pays: 125.00, patient_pays: 25.00, ... }
  #
  # Note: Estimates can ONLY be calculated for verified insurance.
  #
  class InsuranceEstimateService < BaseService
    # Standard disclaimer text for all estimates
    DISCLAIMER = "This is an estimate only and not a guarantee of payment. " \
                 "Actual costs may vary based on services provided, claim processing, " \
                 "and your specific insurance plan details. Please contact your insurance " \
                 "provider for more information."

    # Default therapy session rate (fallback if SessionRate not found)
    DEFAULT_THERAPY_RATE = BigDecimal("150.00")

    # Plan type constants
    PLAN_TYPE_HMO = "HMO"
    PLAN_TYPE_PPO = "PPO"
    PLAN_TYPE_HIGH_DEDUCTIBLE = "HDHP"

    attr_reader :insurance, :service_type, :session_rate

    # Initialize the service
    #
    # @param insurance [Insurance] The insurance record (must be verified)
    # @param service_type [String] Type of service (default: 'individual_therapy')
    def initialize(insurance:, service_type: "individual_therapy")
      @insurance = insurance
      @service_type = service_type
      @session_rate = nil
    end

    # Calculate cost estimate
    #
    # @return [Hash] Cost estimate breakdown
    # @raise [ArgumentError] If insurance not verified or coverage data incomplete
    def call
      validate_insurance!

      # Check cache first
      cached_estimate = fetch_cached_estimate
      return cached_estimate if cached_estimate.present?

      # Calculate estimate
      estimate = calculate_estimate

      # Cache the result
      cache_estimate(estimate)

      estimate
    end

    private

    # Validate insurance is verified and has coverage data
    def validate_insurance!
      # H2 FIX: Don't expose verification_status (PHI) in error messages
      unless insurance.eligibility_verified?
        raise ArgumentError, "Insurance must be verified before calculating estimate"
      end

      unless insurance.verification_result.present?
        raise ArgumentError, "Insurance verification_result is missing"
      end

      coverage = insurance.verification_result.dig("coverage")
      unless coverage.present?
        raise ArgumentError, "Insurance coverage data is incomplete"
      end
    end

    # Calculate the cost estimate
    #
    # @return [Hash] Estimate with all required fields
    def calculate_estimate
      # Get base rates
      billed_amount = fetch_billed_amount
      allowed_amount = calculate_allowed_amount(billed_amount)

      # Determine plan type
      plan_type = determine_plan_type

      # Calculate patient and insurance responsibility
      patient_pays, insurance_pays = calculate_responsibility(
        allowed_amount: allowed_amount,
        plan_type: plan_type
      )

      # Get deductible status
      deductible_status = build_deductible_status

      # Detect coverage limitations
      limitations = detect_coverage_limitations

      {
        insurance_pays: round_currency(insurance_pays),
        patient_pays: round_currency(patient_pays),
        allowed_amount: round_currency(allowed_amount),
        billed_amount: round_currency(billed_amount),
        deductible_status: deductible_status,
        coverage_limitations: limitations,
        is_estimate: true,
        disclaimer: DISCLAIMER,
        calculated_at: Time.current.iso8601
      }
    end

    # Fetch the provider's billed amount (standard rate)
    #
    # @return [BigDecimal] Billed amount
    def fetch_billed_amount
      rate = SessionRate.current_rate_for(service_type: service_type, date: Date.current)

      if rate
        @session_rate = rate
        rate.base_rate
      else
        Rails.logger.warn("No SessionRate found for #{service_type}, using default")
        DEFAULT_THERAPY_RATE
      end
    end

    # Calculate allowed amount based on network status and contracts
    #
    # For in-network: Use contracted rate (typically 80-90% of billed)
    # For out-of-network: May use billed amount or UCR
    #
    # @param billed_amount [BigDecimal] The billed amount
    # @return [BigDecimal] Allowed amount
    def calculate_allowed_amount(billed_amount)
      coverage = insurance.verification_result["coverage"]

      # Check if allowed amount is specified in verification result
      if coverage.dig("allowed_amount").present?
        return BigDecimal(coverage["allowed_amount"].to_s)
      end

      # For in-network, apply typical contract discount (85% of billed)
      # This is a simplified calculation - in production, would look up
      # actual contracted rates from payer agreements
      network_status = coverage.dig("network_status") || "in_network"

      if network_status == "in_network"
        billed_amount * BigDecimal("0.85")
      else
        # Out of network - may use billed amount
        billed_amount
      end
    end

    # Determine plan type from coverage data
    #
    # @return [String] Plan type (HMO, PPO, or HDHP)
    def determine_plan_type
      coverage = insurance.verification_result["coverage"]

      # Try to get explicit plan_type
      explicit_type = coverage.dig("plan_type")
      return explicit_type if explicit_type.present?

      # Infer from coverage structure
      copay = insurance.copay_amount
      deductible = insurance.deductible_amount
      coinsurance = insurance.coinsurance_percentage

      if copay.present? && copay.positive?
        # Copay-based plans are typically HMO
        PLAN_TYPE_HMO
      elsif deductible.present? && deductible >= 1400 # IRS HDHP minimum for 2024
        # High deductible
        PLAN_TYPE_HIGH_DEDUCTIBLE
      elsif coinsurance.present?
        # Coinsurance after deductible is typical PPO
        PLAN_TYPE_PPO
      else
        # Default to PPO if unclear
        PLAN_TYPE_PPO
      end
    end

    # Calculate patient and insurance responsibility
    #
    # @param allowed_amount [BigDecimal] The allowed amount
    # @param plan_type [String] The plan type
    # @return [Array<BigDecimal, BigDecimal>] [patient_pays, insurance_pays]
    def calculate_responsibility(allowed_amount:, plan_type:)
      deductible_amount = insurance.deductible_amount || 0
      deductible_met = insurance.deductible_met || 0
      deductible_remaining = [ deductible_amount - deductible_met, 0 ].max

      copay = insurance.copay_amount || 0
      coinsurance_pct = insurance.coinsurance_percentage || 0

      patient_pays = BigDecimal("0")
      insurance_pays = BigDecimal("0")

      case plan_type
      when PLAN_TYPE_HMO
        # HMO: Simple copay (deductible typically doesn't apply to office visits)
        patient_pays = BigDecimal(copay.to_s)
        insurance_pays = allowed_amount - patient_pays

      when PLAN_TYPE_HIGH_DEDUCTIBLE
        # HDHP: Patient pays everything until deductible met, then coinsurance
        if deductible_remaining.positive?
          # Deductible not met - patient pays up to remaining deductible
          patient_pays = [ allowed_amount, deductible_remaining ].min
          insurance_pays = allowed_amount - patient_pays
        else
          # Deductible met - apply coinsurance
          patient_pays = allowed_amount * (coinsurance_pct / 100.0)
          insurance_pays = allowed_amount - patient_pays
        end

      when PLAN_TYPE_PPO
        # PPO: Deductible first, then coinsurance or copay
        if deductible_remaining.positive?
          # Deductible not met - patient pays toward deductible
          patient_pays = [ allowed_amount, deductible_remaining ].min
          insurance_pays = allowed_amount - patient_pays
        else
          # Deductible met - apply copay or coinsurance
          if copay.positive?
            patient_pays = BigDecimal(copay.to_s)
            insurance_pays = allowed_amount - patient_pays
          elsif coinsurance_pct.positive?
            patient_pays = allowed_amount * (coinsurance_pct / 100.0)
            insurance_pays = allowed_amount - patient_pays
          else
            # No copay or coinsurance - insurance covers all
            insurance_pays = allowed_amount
            patient_pays = BigDecimal("0")
          end
        end
      end

      # Ensure amounts don't go negative
      patient_pays = [ patient_pays, BigDecimal("0") ].max
      insurance_pays = [ insurance_pays, BigDecimal("0") ].max

      [ patient_pays, insurance_pays ]
    end

    # Build deductible status hash
    #
    # @return [Hash] Deductible status information
    def build_deductible_status
      deductible_amount = insurance.deductible_amount || 0
      deductible_met = insurance.deductible_met || 0
      deductible_remaining = [ deductible_amount - deductible_met, 0 ].max

      {
        amount: round_currency(deductible_amount),
        met: round_currency(deductible_met),
        remaining: round_currency(deductible_remaining),
        is_met: deductible_remaining.zero?
      }
    end

    # Detect coverage limitations from verification result
    #
    # @return [Array<String>] Array of limitation messages
    def detect_coverage_limitations
      limitations = []
      coverage = insurance.verification_result["coverage"]

      # Check for session limits
      session_limit = coverage.dig("session_limit")
      if session_limit.present?
        sessions_used = coverage.dig("sessions_used") || 0
        sessions_remaining = session_limit - sessions_used
        if sessions_remaining <= 10
          limitations << "Your plan has a limit of #{session_limit} sessions per year. " \
                        "#{sessions_remaining} sessions remaining."
        end
      end

      # Check for prior authorization requirements
      requires_prior_auth = coverage.dig("requires_prior_authorization")
      if requires_prior_auth == true
        limitations << "Prior authorization may be required for continued treatment."
      end

      # Check for network restrictions
      network_status = coverage.dig("network_status")
      if network_status == "out_of_network"
        limitations << "This provider is out-of-network. Out-of-network benefits may have " \
                      "higher out-of-pocket costs."
      end

      # Check for termination date
      termination_date_str = coverage.dig("termination_date")
      if termination_date_str.present?
        begin
          termination_date = Date.parse(termination_date_str)
          days_until = (termination_date - Date.current).to_i
          if days_until.positive? && days_until <= 30
            limitations << "Your coverage ends on #{termination_date.strftime('%B %d, %Y')}."
          end
        rescue Date::Error
          # Ignore invalid dates
        end
      end

      limitations
    end

    # Fetch cached estimate if available and valid
    #
    # @return [Hash, nil] Cached estimate or nil
    def fetch_cached_estimate
      return nil unless Rails.cache.present?

      cache_key = estimate_cache_key
      Rails.cache.read(cache_key)
    rescue StandardError => e
      Rails.logger.warn("Failed to read estimate cache: #{e.message}")
      nil
    end

    # Cache the estimate
    #
    # @param estimate [Hash] The estimate to cache
    def cache_estimate(estimate)
      return unless Rails.cache.present?

      cache_key = estimate_cache_key
      Rails.cache.write(cache_key, estimate, expires_in: 24.hours)
    rescue StandardError => e
      Rails.logger.warn("Failed to cache estimate: #{e.message}")
    end

    # Generate cache key for estimate
    #
    # @return [String] Cache key
    def estimate_cache_key
      verified_at = insurance.verified_at&.to_i || Time.current.to_i
      deductible_met = insurance.deductible_met || 0

      # M4 FIX: Add hash component to prevent cache poisoning
      # Include coverage data hash to detect any changes in verification result
      coverage_hash = Digest::SHA256.hexdigest(insurance.verification_result.to_json)[0..15]

      "insurance:estimate:#{insurance.id}:#{verified_at}:#{deductible_met}:#{service_type}:#{coverage_hash}"
    end

    # Round currency to 2 decimal places
    #
    # @param amount [Numeric] The amount to round
    # @return [BigDecimal] Rounded amount
    def round_currency(amount)
      BigDecimal(amount.to_s).round(2)
    end
  end
end
