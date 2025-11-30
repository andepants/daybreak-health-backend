# frozen_string_literal: true

module Billing
  # Service for calculating therapy session costs
  #
  # Calculates costs based on:
  # - Base rate from SessionRate model (by service type)
  # - Duration modifiers (prorated by minutes)
  # - Therapist tier modifiers (standard, senior, etc.)
  # - Tax calculations (optional, based on jurisdiction)
  # - Discount codes or hardship adjustments
  #
  # Returns structured breakdown with:
  # - gross_cost: Base cost before adjustments
  # - adjustments: Array of line items (type, description, amount, percentage)
  # - net_cost: Final cost after all adjustments
  # - metadata: calculation timestamp, inputs, etc.
  #
  # Example usage:
  #   result = Billing::CostCalculationService.call(
  #     service_type: 'individual_therapy',
  #     duration: 50,
  #     therapist_tier: 'standard'
  #   )
  #   # => { gross_cost: 150.00, adjustments: [...], net_cost: 150.00 }
  #
  # Calculation is deterministic: same inputs always produce same output
  #
  class CostCalculationService < BaseService
    # Default session duration in minutes
    DEFAULT_DURATION = 50

    # Standard therapist tier multipliers
    THERAPIST_TIER_MULTIPLIERS = {
      "standard" => 1.0,
      "senior" => 1.2,
      "lead" => 1.4,
      "specialist" => 1.5
    }.freeze

    # Special service fees (flat amounts in USD)
    SPECIAL_SERVICE_FEES = {
      "telehealth_setup" => 10.0,
      "translation" => 25.0,
      "assessment_materials" => 15.0
    }.freeze

    attr_reader :service_type, :duration, :therapist_tier, :special_services,
                :discount_code, :tax_rate, :date, :discount_code_invalid

    def initialize(service_type:, duration: nil, therapist_tier: nil,
                   special_services: [], discount_code: nil,
                   tax_rate: nil, date: nil)
      @service_type = service_type
      @duration = duration || DEFAULT_DURATION
      @therapist_tier = therapist_tier || "standard"
      @special_services = special_services || []
      @discount_code = discount_code
      @discount_code_invalid = false
      @tax_rate = tax_rate || begin
        ENV.fetch("TAX_RATE") do
          Rails.logger.warn("TAX_RATE environment variable not set, defaulting to 0")
          "0"
        end.to_f
      end
      @date = date || Date.current
    end

    # Calculate cost breakdown
    #
    # @return [Hash] Cost breakdown with gross_cost, adjustments, net_cost
    # @raise [ArgumentError] If service type is invalid or rate not found
    def call
      validate_inputs!

      # Get base rate
      base_rate = fetch_base_rate

      # Initialize calculation
      gross_cost = calculate_gross_cost(base_rate)
      adjustments = []
      running_total = gross_cost

      # Apply duration modifier
      if duration != DEFAULT_DURATION
        adjustment = apply_duration_modifier(gross_cost)
        adjustments << adjustment
        running_total += adjustment[:amount]
      end

      # Apply therapist tier modifier
      if therapist_tier != "standard"
        adjustment = apply_therapist_tier_modifier(base_rate)
        adjustments << adjustment
        running_total += adjustment[:amount]
      end

      # Apply special service fees
      special_services.each do |service|
        adjustment = apply_special_service_fee(service)
        adjustments << adjustment
        running_total += adjustment[:amount]
      end

      # Apply tax
      if tax_rate.positive?
        adjustment = apply_tax(running_total)
        adjustments << adjustment
        running_total += adjustment[:amount]
      end

      # Apply discount
      if discount_code.present?
        discount_amount = calculate_discount_amount(running_total)
        if discount_amount > 0
          adjustment = {
            type: "discount",
            description: "Discount applied",
            amount: round_currency(-discount_amount),
            percentage: nil
          }
          adjustments << adjustment
          running_total += adjustment[:amount]
        end
      end

      # Ensure net cost is never negative
      net_cost = [ running_total, 0 ].max

      # Return structured breakdown
      {
        gross_cost: round_currency(gross_cost),
        adjustments: adjustments,
        net_cost: round_currency(net_cost),
        currency: "USD",
        calculated_at: Time.current.iso8601,
        discount_code_invalid: discount_code_invalid,
        metadata: {
          service_type: service_type,
          duration: duration,
          therapist_tier: therapist_tier,
          special_services: special_services,
          date: date.iso8601
        }
      }
    end

    private

    # Validate inputs before calculation
    def validate_inputs!
      unless SessionRate.service_types.key?(service_type)
        raise ArgumentError, "Invalid service_type: #{service_type}. " \
                             "Must be one of: #{SessionRate.service_types.keys.join(', ')}"
      end

      if duration <= 0
        raise ArgumentError, "Duration must be positive, got: #{duration}"
      end

      unless THERAPIST_TIER_MULTIPLIERS.key?(therapist_tier)
        raise ArgumentError, "Invalid therapist_tier: #{therapist_tier}. " \
                             "Must be one of: #{THERAPIST_TIER_MULTIPLIERS.keys.join(', ')}"
      end

      special_services.each do |service|
        unless SPECIAL_SERVICE_FEES.key?(service)
          raise ArgumentError, "Invalid special_service: #{service}. " \
                               "Must be one of: #{SPECIAL_SERVICE_FEES.keys.join(', ')}"
        end
      end
    end

    # Fetch base rate from SessionRate model
    #
    # @param base_rate [SessionRate] The base rate record
    # @return [BigDecimal] The base rate amount
    # @raise [ArgumentError] If rate not found
    def fetch_base_rate
      rate = SessionRate.current_rate_for(service_type: service_type, date: date)

      unless rate
        raise ArgumentError, "No rate found for service_type: #{service_type} on #{date}"
      end

      rate.base_rate
    end

    # Calculate gross cost (base rate for standard duration)
    #
    # @param base_rate [BigDecimal] The base rate amount
    # @return [BigDecimal] The gross cost
    def calculate_gross_cost(base_rate)
      base_rate
    end

    # Apply duration modifier (prorated by minutes)
    #
    # Duration modifier is applied as a percentage adjustment
    # based on the ratio of actual duration to default duration.
    #
    # @param gross_cost [BigDecimal] The gross cost
    # @return [Hash] Adjustment hash
    def apply_duration_modifier(gross_cost)
      # Calculate percentage difference from default duration
      duration_ratio = duration.to_f / DEFAULT_DURATION
      adjustment_amount = gross_cost * (duration_ratio - 1.0)

      {
        type: "duration_modifier",
        description: "Session duration: #{duration} minutes (standard: #{DEFAULT_DURATION})",
        amount: round_currency(adjustment_amount),
        percentage: ((duration_ratio - 1.0) * 100).round(2)
      }
    end

    # Apply therapist tier modifier
    #
    # @param base_rate [BigDecimal] The base rate amount
    # @return [Hash] Adjustment hash
    def apply_therapist_tier_modifier(base_rate)
      multiplier = THERAPIST_TIER_MULTIPLIERS[therapist_tier]
      adjustment_amount = base_rate * (multiplier - 1.0)

      {
        type: "therapist_tier",
        description: "Therapist tier: #{therapist_tier.titleize}",
        amount: round_currency(adjustment_amount),
        percentage: ((multiplier - 1.0) * 100).round(2)
      }
    end

    # Apply special service fee
    #
    # @param service [String] The special service name
    # @return [Hash] Adjustment hash
    def apply_special_service_fee(service)
      fee = SPECIAL_SERVICE_FEES[service] || 0

      {
        type: "special_service",
        description: "Special service: #{service.titleize}",
        amount: round_currency(fee),
        percentage: nil
      }
    end

    # Apply tax calculation
    #
    # @param subtotal [BigDecimal] The subtotal before tax
    # @return [Hash] Adjustment hash
    def apply_tax(subtotal)
      tax_amount = subtotal * tax_rate

      {
        type: "tax",
        description: "Tax (#{(tax_rate * 100).round(2)}%)",
        amount: round_currency(tax_amount),
        percentage: (tax_rate * 100).round(2)
      }
    end

    # Calculate discount amount from discount code
    #
    # @param subtotal [BigDecimal] The subtotal before discount
    # @return [BigDecimal] The discount amount (positive value)
    def calculate_discount_amount(subtotal)
      return 0 unless discount_code.present?

      # Extract discount type and value first to avoid timing attacks
      # All regex checks happen upfront, before any branching based on validity
      percentage_match = discount_code.match(/^PERCENTAGE_(\d+)$/)
      fixed_match = discount_code.match(/^FIXED_(\d+)$/)
      hardship_match = discount_code.match(/^HARDSHIP_(\d+)$/)

      # Process based on which pattern matched
      if percentage_match
        # Percentage discount (e.g., PERCENTAGE_10 = 10% off)
        percentage = percentage_match[1].to_f
        subtotal * (percentage / 100.0)
      elsif fixed_match
        # Fixed amount discount (e.g., FIXED_25 = $25 off)
        fixed_match[1].to_f
      elsif hardship_match
        # Hardship discount (e.g., HARDSHIP_50 = 50% off)
        percentage = hardship_match[1].to_f
        subtotal * (percentage / 100.0)
      else
        # Invalid code - log warning, set flag, and apply no discount
        Rails.logger.warn("Invalid discount code: #{discount_code}")
        @discount_code_invalid = true
        0
      end
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
