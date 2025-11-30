# frozen_string_literal: true

module Billing
  # Service for calculating payment plan options
  #
  # Calculates payment plan options for therapy costs:
  # - Upfront payment option with discount
  # - Monthly payment plans (3, 6, 12 months)
  # - Interest/fee calculations
  # - Monthly payment amounts
  #
  # Returns array of plan options with:
  # - duration_months: Plan duration (0 for upfront, 3/6/12 for plans)
  # - monthly_amount: Monthly payment amount
  # - total_amount: Total cost including interest/fees
  # - interest_rate: Annual interest rate (default 0% for MVP)
  # - has_fees: Whether plan has fees
  # - fee_amount: Total fee amount
  # - upfront_discount: Discount percentage for upfront payment
  # - description: Human-readable plan description
  #
  # Example usage:
  #   result = Billing::PaymentPlanService.call(
  #     total_amount: 1200.00
  #   )
  #   # => [
  #   #   { duration_months: 0, total_amount: 1140.00, upfront_discount: 5, ... },
  #   #   { duration_months: 3, monthly_amount: 400.00, total_amount: 1200.00, ... },
  #   #   { duration_months: 6, monthly_amount: 200.00, total_amount: 1200.00, ... },
  #   #   { duration_months: 12, monthly_amount: 100.00, total_amount: 1200.00, ... }
  #   # ]
  #
  class PaymentPlanService < BaseService
    # Default plan durations in months
    DEFAULT_DURATIONS = [ 3, 6, 12 ].freeze

    # Default upfront payment discount percentage
    DEFAULT_UPFRONT_DISCOUNT = 5.0

    # Default interest rate (0% for MVP - no predatory terms)
    DEFAULT_INTEREST_RATE = 0.0

    # Default service fees (0 for MVP)
    DEFAULT_SERVICE_FEES = 0.0

    attr_reader :total_amount, :durations, :upfront_discount, :interest_rates, :service_fees

    # Initialize payment plan service
    #
    # @param total_amount [Numeric] Total cost to calculate plans for
    # @param options [Hash] Optional configuration
    # @option options [Array<Integer>] :durations Plan durations in months
    # @option options [Numeric] :upfront_discount Upfront payment discount percentage
    # @option options [Hash] :interest_rates Interest rates by duration (e.g., {3 => 0, 6 => 0, 12 => 0})
    # @option options [Hash] :service_fees Service fees by duration (e.g., {3 => 0, 6 => 0, 12 => 0})
    def initialize(total_amount:, options: {})
      @total_amount = BigDecimal(total_amount.to_s)
      @durations = options[:durations] || load_config_durations || DEFAULT_DURATIONS
      @upfront_discount = options[:upfront_discount] || load_config_upfront_discount || DEFAULT_UPFRONT_DISCOUNT
      @interest_rates = options[:interest_rates] || load_config_interest_rates || {}
      @service_fees = options[:service_fees] || load_config_service_fees || {}
    end

    # Calculate payment plan options
    #
    # @return [Array<Hash>] Array of payment plan options
    # @raise [ArgumentError] If total amount is invalid
    def call
      validate_inputs!

      plans = []

      # Add upfront payment option with discount
      plans << calculate_upfront_plan

      # Add monthly payment plans
      durations.each do |duration|
        plans << calculate_monthly_plan(duration)
      end

      plans
    end

    private

    # Validate inputs before calculation
    def validate_inputs!
      if total_amount <= 0
        raise ArgumentError, "Total amount must be positive, got: #{total_amount}"
      end

      durations.each do |duration|
        unless duration.is_a?(Integer) && duration.positive?
          raise ArgumentError, "Invalid duration: #{duration}. Must be positive integer."
        end
      end

      unless upfront_discount >= 0 && upfront_discount <= 100
        raise ArgumentError, "Upfront discount must be between 0 and 100, got: #{upfront_discount}"
      end
    end

    # Calculate upfront payment plan with discount
    #
    # @return [Hash] Upfront payment plan details
    def calculate_upfront_plan
      discount_amount = total_amount * (upfront_discount / 100.0)
      discounted_total = total_amount - discount_amount

      {
        duration_months: 0,
        monthly_amount: round_currency(discounted_total),
        total_amount: round_currency(discounted_total),
        interest_rate: 0.0,
        has_fees: false,
        fee_amount: 0.0,
        upfront_discount: upfront_discount,
        description: "Pay in full now (#{upfront_discount}% discount)"
      }
    end

    # Calculate monthly payment plan
    #
    # @param duration [Integer] Plan duration in months
    # @return [Hash] Monthly payment plan details
    def calculate_monthly_plan(duration)
      interest_rate = interest_rates[duration] || DEFAULT_INTEREST_RATE
      service_fee = service_fees[duration] || DEFAULT_SERVICE_FEES

      # Calculate total with interest and fees
      # For MVP: interest_rate = 0, service_fee = 0
      interest_amount = calculate_interest(total_amount, interest_rate, duration)
      total_with_interest_and_fees = total_amount + interest_amount + service_fee

      # Calculate monthly payment (rounded to 2 decimal places)
      monthly_amount = total_with_interest_and_fees / duration

      has_fees = service_fee > 0 || interest_rate > 0

      {
        duration_months: duration,
        monthly_amount: round_currency(monthly_amount),
        total_amount: round_currency(total_with_interest_and_fees),
        interest_rate: interest_rate,
        has_fees: has_fees,
        fee_amount: round_currency(interest_amount + service_fee),
        upfront_discount: nil,
        description: "#{duration} monthly payments of #{format_currency(monthly_amount)}"
      }
    end

    # Calculate interest amount
    #
    # For MVP, interest is 0%. This method supports future interest calculations.
    # Uses simple interest calculation: principal * rate * (months/12)
    #
    # @param principal [BigDecimal] Principal amount
    # @param annual_rate [Numeric] Annual interest rate as percentage (e.g., 5 for 5%)
    # @param months [Integer] Number of months
    # @return [BigDecimal] Interest amount
    def calculate_interest(principal, annual_rate, months)
      return BigDecimal("0") if annual_rate.zero?

      # Simple interest: P * r * t (where t is in years)
      principal * (annual_rate / 100.0) * (months / 12.0)
    end

    # Round currency to 2 decimal places
    #
    # @param amount [Numeric] The amount to round
    # @return [BigDecimal] Rounded amount
    def round_currency(amount)
      BigDecimal(amount.to_s).round(2)
    end

    # Format currency for display
    #
    # @param amount [Numeric] The amount to format
    # @return [String] Formatted currency string
    def format_currency(amount)
      "$#{round_currency(amount).to_f}"
    end

    # Load plan durations from config
    #
    # @return [Array<Integer>, nil] Plan durations or nil if not configured
    def load_config_durations
      return nil unless Rails.application.config.respond_to?(:payment_plans)

      Rails.application.config.payment_plans&.dig(:plan_durations)
    end

    # Load upfront discount from config
    #
    # @return [Numeric, nil] Upfront discount percentage or nil if not configured
    def load_config_upfront_discount
      return nil unless Rails.application.config.respond_to?(:payment_plans)

      Rails.application.config.payment_plans&.dig(:upfront_discount_percentage)
    end

    # Load interest rates from config
    #
    # @return [Hash, nil] Interest rates by duration or nil if not configured
    def load_config_interest_rates
      return nil unless Rails.application.config.respond_to?(:payment_plans)

      Rails.application.config.payment_plans&.dig(:interest_rates) || {}
    end

    # Load service fees from config
    #
    # @return [Hash, nil] Service fees by duration or nil if not configured
    def load_config_service_fees
      return nil unless Rails.application.config.respond_to?(:payment_plans)

      Rails.application.config.payment_plans&.dig(:service_fees) || {}
    end
  end
end
