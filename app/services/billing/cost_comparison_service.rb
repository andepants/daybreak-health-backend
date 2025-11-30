# frozen_string_literal: true

module Billing
  # Service for comparing insurance estimates with self-pay rates
  #
  # Provides side-by-side comparison of insurance costs vs. self-pay options
  # to help parents make informed financial decisions about therapy.
  #
  # Features:
  # - Insurance estimate calculation (if verified)
  # - Self-pay rate lookup with sliding scale and package options
  # - High deductible detection and recommendations
  # - Comparison table generation
  # - Savings calculation when self-pay is more affordable
  #
  # Example usage:
  #   result = Billing::CostComparisonService.new(session_id).calculate_comparison
  #   # => {
  #   #   insurance_estimate: { per_session_cost: "$150.00", ... },
  #   #   self_pay_estimate: { base_rate: "$75 per session", ... },
  #   #   comparison_table: [...],
  #   #   recommendation: "Self-pay may be more affordable",
  #   #   savings_if_self_pay: 600.0,
  #   #   highlight_self_pay: true
  #   # }
  #
  class CostComparisonService < BaseService
    # Typical session count for treatment estimates
    TYPICAL_SESSION_MIN = 8
    TYPICAL_SESSION_MAX = 12

    # High deductible threshold for recommendations
    HIGH_DEDUCTIBLE_THRESHOLD = 1000

    attr_reader :session, :insurance, :child

    # Initialize the service
    #
    # @param session_id [String] The onboarding session ID
    def initialize(session_id)
      @session = OnboardingSession.includes(:insurance, :child).find(session_id)
      @insurance = @session.insurance
      @child = @session.child
    end

    # Calculate comprehensive cost comparison
    #
    # @return [Hash] Cost comparison with estimates, table, and recommendation
    def call
      {
        insurance_estimate: calculate_insurance_estimate,
        self_pay_estimate: calculate_self_pay_estimate,
        comparison_table: generate_comparison_table,
        recommendation: generate_recommendation,
        savings_if_self_pay: calculate_savings_if_self_pay,
        highlight_self_pay: should_highlight_self_pay?
      }
    end

    private

    # Calculate insurance estimate if verified
    #
    # @return [Hash, nil] Insurance estimate or nil if not verified
    def calculate_insurance_estimate
      return nil unless insurance&.eligibility_verified?

      # Use InsuranceEstimateService to get detailed estimate
      estimate = Billing::InsuranceEstimateService.call(
        insurance: insurance,
        service_type: "individual_therapy"
      )

      copay = insurance.copay_amount || 0
      deductible_remaining = calculate_deductible_remaining
      coinsurance = insurance.coinsurance_percentage || 0

      # Calculate per-session cost based on deductible status
      per_session_cost = if deductible_remaining > 0
                           # Before deductible met: patient pays full allowed amount
                           estimate[:allowed_amount]
      elsif copay > 0
                           # After deductible: copay applies
                           copay
      elsif coinsurance > 0
                           # After deductible: coinsurance applies
                           estimate[:allowed_amount] * (coinsurance / 100.0)
      else
                           # No cost sharing
                           BigDecimal("0")
      end

      # Calculate total for typical treatment
      total_estimated_cost = (per_session_cost * TYPICAL_SESSION_MIN) +
                            ([ deductible_remaining, 0 ].max)

      {
        per_session_cost: format_currency(per_session_cost),
        total_estimated_cost: format_currency(total_estimated_cost),
        explanation: generate_insurance_explanation(estimate),
        assumption_notes: generate_assumption_notes
      }
    rescue ArgumentError => e
      Rails.logger.warn("Insurance estimate failed: #{e.message}")
      nil
    end

    # Calculate self-pay estimate (always available)
    #
    # @return [Hash] Self-pay estimate with rates and options
    def calculate_self_pay_estimate
      rate = SelfPayRate.get_rate_for("individual_therapy")

      # Fallback to default rate if no active rate found
      base_rate = rate&.base_rate || BigDecimal("75.00")

      # Calculate total for typical treatment
      typical_total = base_rate * TYPICAL_SESSION_MIN

      {
        base_rate: "#{format_currency(base_rate)} per session",
        total_for_typical_treatment: format_currency(typical_total),
        sliding_scale_info: generate_sliding_scale_info(rate),
        package_options: generate_package_options(rate),
        transparent_pricing_message: "No surprise fees. Price shown is what you pay.",
        what_is_included: [
          "50-minute session",
          "Secure messaging between sessions",
          "Treatment planning and notes"
        ],
        what_is_not_included: [
          "Medication management (requires separate psychiatry visit)"
        ]
      }
    end

    # Generate comparison table rows
    #
    # @return [Array<Hash>] Comparison table rows
    def generate_comparison_table
      rows = []
      insurance_est = calculate_insurance_estimate
      self_pay_est = calculate_self_pay_estimate
      rate = SelfPayRate.get_rate_for("individual_therapy")
      base_rate = rate&.base_rate || BigDecimal("75.00")

      # Row: Per Session Cost
      if insurance_est
        deductible_remaining = calculate_deductible_remaining
        copay = insurance.copay_amount || 0

        insurance_per_session = if deductible_remaining > 0
                                  insurance_est[:per_session_cost]
        else
                                  format_currency(copay > 0 ? copay : base_rate)
        end
      else
        insurance_per_session = nil
      end

      rows << {
        label: "Per Session Cost",
        insurance_value: insurance_per_session,
        self_pay_value: format_currency(base_rate),
        highlight_self_pay: insurance_per_session ? base_rate < parse_currency(insurance_per_session) : false
      }

      # Row: Typical Treatment (8-12 sessions)
      typical_self_pay = base_rate * TYPICAL_SESSION_MIN
      rows << {
        label: "Typical Treatment (#{TYPICAL_SESSION_MIN}-#{TYPICAL_SESSION_MAX} sessions)",
        insurance_value: insurance_est ? insurance_est[:total_estimated_cost] : nil,
        self_pay_value: format_currency(typical_self_pay),
        highlight_self_pay: insurance_est ? typical_self_pay < parse_currency(insurance_est[:total_estimated_cost]) : false
      }

      # Row: Out-of-Pocket Before Deductible Met
      if insurance_est
        deductible_remaining = calculate_deductible_remaining
        rows << {
          label: "Out-of-Pocket Before Deductible Met",
          insurance_value: format_currency(deductible_remaining),
          self_pay_value: format_currency(base_rate),
          highlight_self_pay: (deductible_remaining > 0 && base_rate < deductible_remaining) || false
        }
      end

      # Row: After Deductible Met
      if insurance_est
        copay = insurance.copay_amount || 0
        rows << {
          label: "After Deductible Met",
          insurance_value: format_currency(copay > 0 ? copay : 0),
          self_pay_value: format_currency(base_rate),
          highlight_self_pay: base_rate < copay
        }
      end

      rows
    end

    # Generate personalized recommendation
    #
    # @return [String, nil] Recommendation text or nil
    def generate_recommendation
      return nil unless insurance&.eligibility_verified?

      deductible_remaining = calculate_deductible_remaining
      rate = SelfPayRate.get_rate_for("individual_therapy")
      base_rate = rate&.base_rate || BigDecimal("75.00")

      # High deductible detection
      if deductible_remaining > HIGH_DEDUCTIBLE_THRESHOLD
        savings = calculate_savings_if_self_pay
        if savings && savings > 0
          "Self-pay may be more affordable. With your high deductible plan, " \
          "you could save approximately #{format_currency(savings)} by choosing self-pay " \
          "for the first #{TYPICAL_SESSION_MIN} sessions."
        end
      elsif deductible_remaining > 0 && base_rate < deductible_remaining
        "Consider self-pay while meeting your deductible. Each self-pay session costs " \
        "#{format_currency(base_rate)}, which may be less than your insurance responsibility."
      else
        copay = insurance.copay_amount || 0
        if copay > 0 && copay < base_rate
          "Your insurance copay of #{format_currency(copay)} is lower than self-pay. " \
          "Using insurance is recommended."
        end
      end
    end

    # Calculate savings if choosing self-pay
    #
    # @return [Float, nil] Savings amount or nil
    def calculate_savings_if_self_pay
      return nil unless insurance&.eligibility_verified?

      insurance_est = calculate_insurance_estimate
      return nil unless insurance_est

      self_pay_est = calculate_self_pay_estimate

      insurance_total = parse_currency(insurance_est[:total_estimated_cost])
      self_pay_total = parse_currency(self_pay_est[:total_for_typical_treatment])

      savings = insurance_total - self_pay_total
      savings > 0 ? savings.to_f : nil
    end

    # Determine if self-pay should be highlighted
    #
    # @return [Boolean] True if self-pay is the better option
    def should_highlight_self_pay?
      return false unless insurance&.eligibility_verified?

      deductible_remaining = calculate_deductible_remaining
      savings = calculate_savings_if_self_pay

      # Highlight if high deductible and savings exist
      deductible_remaining > HIGH_DEDUCTIBLE_THRESHOLD && savings && savings > 0
    end

    # Calculate remaining deductible (memoized for performance)
    #
    # @return [BigDecimal] Remaining deductible amount
    def calculate_deductible_remaining
      @deductible_remaining ||= begin
        return BigDecimal("0") unless insurance

        deductible_amount = insurance.deductible_amount || 0
        deductible_met = insurance.deductible_met || 0
        [ deductible_amount - deductible_met, 0 ].max
      end
    end

    # Generate insurance explanation text
    #
    # @param estimate [Hash] Insurance estimate from InsuranceEstimateService
    # @return [String] Explanation text
    def generate_insurance_explanation(estimate)
      deductible_remaining = calculate_deductible_remaining

      if deductible_remaining > HIGH_DEDUCTIBLE_THRESHOLD
        "Based on your verified coverage details. You have a high-deductible plan " \
        "with #{format_currency(deductible_remaining)} remaining to meet."
      elsif deductible_remaining > 0
        "Based on your verified coverage details. You have " \
        "#{format_currency(deductible_remaining)} remaining on your deductible."
      else
        "Based on your verified coverage details. Your deductible has been met."
      end
    end

    # Generate assumption notes for insurance estimate
    #
    # @return [Array<String>] Assumption notes
    def generate_assumption_notes
      notes = []
      notes << "Estimates assume in-network provider"
      notes << "Actual costs may vary based on claim processing"
      notes << "Contact your insurance for specific benefit details"
      notes
    end

    # Generate sliding scale information
    #
    # @param rate [SelfPayRate, nil] The active self-pay rate
    # @return [String, nil] Sliding scale info or nil
    def generate_sliding_scale_info(rate)
      return nil unless rate&.sliding_scale_available

      "Sliding scale available based on household income. " \
      "Discounts from 10-50% may apply. Contact us to discuss financial assistance options."
    end

    # Generate package options
    #
    # @param rate [SelfPayRate, nil] The active self-pay rate
    # @return [Array<Hash>] Package options
    def generate_package_options(rate)
      return [] unless rate&.package_pricing_available

      rate.package_options.map do |option|
        sessions = option["sessions"]
        total_price = BigDecimal(option["total_price"].to_s)
        savings = BigDecimal(option["savings"].to_s)
        per_session_cost = total_price / sessions

        {
          sessions: sessions,
          total_price: format_currency(total_price),
          per_session_cost: format_currency(per_session_cost),
          savings: format_currency(savings),
          description: option["description"]
        }
      end.sort_by { |opt| opt[:sessions] }
    end

    # Format currency value
    #
    # @param amount [Numeric] Amount to format
    # @return [String] Formatted currency string
    def format_currency(amount)
      "$%.2f" % amount.to_f
    end

    # Parse currency string to BigDecimal
    #
    # @param currency_str [String] Currency string like "$150.00"
    # @return [BigDecimal] Parsed amount
    def parse_currency(currency_str)
      BigDecimal(currency_str.to_s.gsub(/[$,]/, ""))
    end
  end
end
