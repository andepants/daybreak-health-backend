# frozen_string_literal: true

module Billing
  # Service for tracking deductible progress and out-of-pocket spending
  #
  # Story 6.4: Deductible & Out-of-Pocket Tracking
  # Provides comprehensive deductible and OOP tracking including:
  # - Current deductible status (amount, met, remaining)
  # - Out-of-pocket maximum tracking
  # - Family vs individual plan detection
  # - Session projections until deductible met
  # - Plan year reset dates
  # - Progress percentages for visual indicators
  #
  # Example usage:
  #   tracker = Billing::DeductibleTracker.new(insurance: insurance)
  #   status = tracker.current_status
  #   # => {
  #   #   amount: 500.0,
  #   #   met: 100.0,
  #   #   remaining: 400.0,
  #   #   is_met: false,
  #   #   deductible_amount: 500.0,
  #   #   ...
  #   # }
  #
  class DeductibleTracker < BaseService
    attr_reader :insurance

    # Initialize the tracker
    #
    # @param insurance [Insurance] The insurance record (must be verified)
    def initialize(insurance:)
      @insurance = insurance
    end

    # Get current deductible status
    #
    # @return [Hash] Complete deductible status
    def call
      current_status
    end

    # Get comprehensive deductible and OOP status
    #
    # @return [Hash] Status hash with all tracking fields
    def current_status
      # Get core deductible values
      deductible_amt = deductible_amount
      deductible_met_amt = deductible_met
      deductible_rem = deductible_remaining(deductible_amt, deductible_met_amt)

      # Get OOP max values
      oop_max = insurance.out_of_pocket_max_amount
      oop_met_amt = insurance.out_of_pocket_met
      oop_rem = oop_remaining(oop_max, oop_met_amt)

      # Calculate progress percentages
      deductible_pct = progress_percentage(deductible_met_amt, deductible_amt)
      oop_pct = progress_percentage(oop_met_amt, oop_max)

      # Get plan metadata
      is_family = insurance.is_family_plan?
      reset_date = insurance.plan_year_reset_date

      # Calculate session projection
      sessions_until_met = sessions_until_deductible_met(deductible_rem)

      # Determine data source
      source = data_source
      last_updated = last_updated_at

      {
        # Core fields (backward compatible with existing DeductibleStatusType usage)
        amount: deductible_amt || 0.0,
        met: deductible_met_amt || 0.0,
        remaining: deductible_rem || 0.0,
        is_met: deductible_rem&.zero? || false,

        # Story 6.4: Enhanced deductible tracking
        deductible_amount: deductible_amt,
        deductible_met: deductible_met_amt,
        deductible_remaining: deductible_rem,

        # Story 6.4: OOP max tracking (AC2)
        oop_max_amount: oop_max,
        oop_met: oop_met_amt,
        oop_remaining: oop_rem,

        # Story 6.4: Plan metadata (AC3, AC5)
        is_family_plan: is_family,
        year_reset_date: reset_date,

        # Story 6.4: Progress indicators (AC5)
        progress_percentage: deductible_pct,
        oop_progress_percentage: oop_pct,

        # Story 6.4: Session projection (AC4)
        sessions_until_deductible_met: sessions_until_met,

        # Story 6.4: Data provenance (AC6)
        data_source: source,
        last_updated_at: last_updated
      }
    end

    # Calculate sessions until deductible is met
    #
    # @param remaining [Float, nil] Deductible remaining amount
    # @return [Integer, nil] Number of sessions, or nil if cannot calculate
    def sessions_until_deductible_met(remaining = nil)
      remaining ||= deductible_remaining(deductible_amount, deductible_met)

      # If deductible already met or no remaining amount
      return 0 if remaining.nil? || remaining <= 0

      # Get session cost
      session_cost = session_rate
      return nil if session_cost.nil? || session_cost <= 0

      # Calculate sessions needed (round up)
      (remaining / session_cost).ceil
    end

    # Calculate progress percentage
    #
    # @param met [Float, nil] Amount met
    # @param total [Float, nil] Total amount
    # @return [Integer, nil] Percentage 0-100, or nil if cannot calculate
    def progress_percentage(met, total)
      return 0 if total.nil? || total.zero?
      return nil if met.nil?

      percentage = ((met / total) * 100).round
      [ [ percentage, 0 ].max, 100 ].min # Clamp to 0-100
    end

    private

    # Get deductible amount (with override priority)
    #
    # @return [Float, nil] Deductible amount
    def deductible_amount
      # Check for manual override first
      override = insurance.verification_result&.dig("deductible_override", "deductible_amount")
      return override if override.present?

      # Check for family deductible if family plan
      if insurance.is_family_plan?
        family_ded = insurance.verification_result&.dig("coverage", "family_deductible", "amount")
        return family_ded if family_ded.present?
      end

      # Use standard deductible amount
      insurance.deductible_amount
    end

    # Get deductible met amount (with override priority)
    #
    # @return [Float, nil] Deductible met amount
    def deductible_met
      # Check for manual override first
      override = insurance.verification_result&.dig("deductible_override", "deductible_met")
      return override if override.present?

      # Check for family deductible met if family plan
      if insurance.is_family_plan?
        family_met = insurance.verification_result&.dig("coverage", "family_deductible", "met")
        return family_met if family_met.present?
      end

      # Use standard deductible met
      insurance.deductible_met
    end

    # Calculate deductible remaining
    #
    # @param amount [Float, nil] Total deductible amount
    # @param met [Float, nil] Amount already met
    # @return [Float, nil] Remaining amount
    def deductible_remaining(amount, met)
      return nil if amount.nil?

      met ||= 0
      remaining = amount - met
      [ remaining, 0 ].max # Ensure non-negative
    end

    # Calculate OOP remaining
    #
    # @param max [Float, nil] OOP max amount
    # @param met [Float, nil] OOP met amount
    # @return [Float, nil] OOP remaining
    def oop_remaining(max, met)
      return nil if max.nil?

      met ||= 0
      remaining = max - met
      [ remaining, 0 ].max # Ensure non-negative
    end

    # Get session rate for projection calculations
    #
    # @return [Float, nil] Session rate in dollars
    def session_rate
      rates = Rails.application.config.session_rates
      default_type = Rails.application.config.default_session_type || "individual_therapy"

      rate = rates&.[](default_type)
      return rate if rate.present?

      # Fallback to individual_therapy
      rates&.[]("individual_therapy") || 100.00
    rescue StandardError => e
      Rails.logger.warn("Failed to get session rate: #{e.message}")
      100.00 # Fallback default
    end

    # Determine data source
    #
    # @return [String] Source of data
    def data_source
      # Check for manual override
      if insurance.verification_result&.dig("deductible_override").present?
        return "manual_override"
      end

      # Check if from eligibility API
      if insurance.verified_at.present?
        return "eligibility_api"
      end

      # Cached or unknown
      "cached"
    end

    # Get last updated timestamp
    #
    # @return [Time, nil] Last update time
    def last_updated_at
      # Check manual override timestamp
      override_time = insurance.verification_result&.dig("deductible_override", "override_timestamp")
      return Time.zone.parse(override_time) if override_time.present?

      # Use verification timestamp
      insurance.verified_at
    rescue ArgumentError
      nil
    end
  end
end
