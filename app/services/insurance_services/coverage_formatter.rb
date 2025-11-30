# frozen_string_literal: true

module InsuranceServices
  # Formats insurance coverage details for user-friendly display
  #
  # Converts raw coverage data from verification results into formatted
  # strings that are easy for parents to understand.
  #
  # @example
  #   formatter = Insurance::CoverageFormatter.new(insurance)
  #   details = formatter.format_all
  #   # => { copay_amount: "$25 per visit", ... }
  #
  class CoverageFormatter
    # Default services covered for mental health
    DEFAULT_SERVICES = [
      "Mental health services",
      "Individual therapy",
      "Initial assessment"
    ].freeze

    # @param insurance [Insurance] The insurance record with coverage data
    def initialize(insurance)
      @insurance = insurance
      @coverage = insurance.verification_result&.dig("coverage") || {}
    end

    # Format all coverage details
    #
    # @return [Hash, nil] Formatted coverage details or nil if not verified
    def format_all
      return nil unless @insurance.verified?

      {
        copay_amount: format_copay,
        services_covered: format_services,
        effective_date: format_effective_date,
        deductible: format_deductible,
        coinsurance: format_coinsurance
      }
    end

    # Format copay amount
    #
    # @return [String, nil] Formatted copay like "$25 per visit"
    def format_copay
      copay = @coverage.dig("copay")
      return nil unless copay

      amount = copay["amount"]
      return nil unless amount

      frequency = copay["frequency"] || "visit"
      "$#{format_amount(amount)} per #{frequency}"
    end

    # Format deductible with met amount
    #
    # @return [String, nil] Formatted deductible like "$500 ($100 met)"
    def format_deductible
      deductible = @coverage.dig("deductible")
      return nil unless deductible

      amount = deductible["amount"]
      return nil unless amount

      met = deductible["met"]
      remaining = deductible["remaining"]

      if met.present?
        "$#{format_amount(amount)} ($#{format_amount(met)} met)"
      elsif remaining.present?
        "$#{format_amount(amount)} ($#{format_amount(remaining)} remaining)"
      else
        "$#{format_amount(amount)}"
      end
    end

    # Format services covered
    #
    # @return [Array<String>] List of covered services
    def format_services
      services = @coverage.dig("services_covered")
      return DEFAULT_SERVICES if services.blank?

      services.is_a?(Array) ? services : DEFAULT_SERVICES
    end

    # Format effective date
    #
    # @return [String, nil] Formatted date or nil
    def format_effective_date
      date_str = @coverage.dig("effective_date")
      return nil unless date_str.present?

      begin
        date = Date.parse(date_str)
        date.strftime("%B %d, %Y")
      rescue Date::Error, ArgumentError
        nil
      end
    end

    # Format coinsurance percentage
    #
    # @return [Integer, nil] Coinsurance percentage
    def format_coinsurance
      percentage = @coverage.dig("coinsurance", "percentage")
      return nil unless percentage.is_a?(Numeric)

      percentage.to_i
    end

    # Format out-of-pocket maximum
    #
    # @return [String, nil] Formatted OOP max
    def format_out_of_pocket_max
      oop = @coverage.dig("out_of_pocket_max")
      return nil unless oop

      amount = oop["amount"]
      return nil unless amount

      met = oop["met"]
      if met.present?
        "$#{format_amount(amount)} ($#{format_amount(met)} met)"
      else
        "$#{format_amount(amount)}"
      end
    end

    # Format termination date if coverage is ending soon
    #
    # @return [String, nil] Warning message if coverage ending within 30 days
    def format_termination_warning
      date_str = @coverage.dig("termination_date")
      return nil unless date_str.present?

      begin
        termination_date = Date.parse(date_str)
        days_until = (termination_date - Date.current).to_i

        if days_until.positive? && days_until <= 30
          "Coverage ends #{termination_date.strftime('%B %d, %Y')}"
        end
      rescue Date::Error, ArgumentError
        nil
      end
    end

    private

    # Format a numeric amount as a clean string
    #
    # @param amount [Numeric] The amount to format
    # @return [String] Formatted amount without unnecessary decimals
    def format_amount(amount)
      return "0" unless amount

      # If it's a whole number, don't show decimals
      if amount == amount.to_i
        amount.to_i.to_s
      else
        format("%.2f", amount)
      end
    end
  end
end
