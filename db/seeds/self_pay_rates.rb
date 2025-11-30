# frozen_string_literal: true

# Self-Pay Rates Seed Data
#
# Seeds transparent self-pay pricing for therapy sessions.
# Rates are effective immediately with no end date (ongoing).
#
# Pricing Strategy:
# - Competitive with market rates
# - Lower than typical insurance allowed amounts
# - Includes sliding scale and package options
#
# Based on test data from contracts.csv which shows contracted rates
# of $100-150 for therapy sessions. Self-pay rates are set lower to
# be attractive alternative for high-deductible plans.

puts "Seeding self-pay rates..."

# Current rates effective from project start
effective_date = Date.parse("2024-01-01")

# Individual Therapy Rate
SelfPayRate.find_or_create_by!(
  session_type: "individual_therapy",
  effective_date: effective_date
) do |rate|
  rate.base_rate = 75.00
  rate.end_date = nil # Ongoing
  rate.sliding_scale_available = true
  rate.package_pricing_available = true
  rate.description = "Individual therapy session (50 minutes)"
  rate.metadata = {
    sliding_scale_tiers: [
      { income_range: "0-25000", discount_percent: 50 },
      { income_range: "25001-50000", discount_percent: 30 },
      { income_range: "50001-75000", discount_percent: 20 },
      { income_range: "75001-100000", discount_percent: 10 }
    ],
    package_options: [
      {
        sessions: 4,
        total_price: 280,
        savings: 20,
        description: "4-session bundle - Save $20"
      },
      {
        sessions: 8,
        total_price: 560,
        savings: 40,
        description: "8-session bundle - Save $40"
      },
      {
        sessions: 12,
        total_price: 810,
        savings: 90,
        description: "12-session bundle - Save $90"
      }
    ]
  }
end

# Family Therapy Rate
SelfPayRate.find_or_create_by!(
  session_type: "family_therapy",
  effective_date: effective_date
) do |rate|
  rate.base_rate = 100.00
  rate.end_date = nil # Ongoing
  rate.sliding_scale_available = true
  rate.package_pricing_available = true
  rate.description = "Family therapy session (50 minutes)"
  rate.metadata = {
    sliding_scale_tiers: [
      { income_range: "0-25000", discount_percent: 50 },
      { income_range: "25001-50000", discount_percent: 30 },
      { income_range: "50001-75000", discount_percent: 20 },
      { income_range: "75001-100000", discount_percent: 10 }
    ],
    package_options: [
      {
        sessions: 4,
        total_price: 380,
        savings: 20,
        description: "4-session bundle - Save $20"
      },
      {
        sessions: 8,
        total_price: 760,
        savings: 40,
        description: "8-session bundle - Save $40"
      },
      {
        sessions: 12,
        total_price: 1100,
        savings: 100,
        description: "12-session bundle - Save $100"
      }
    ]
  }
end

# Intake Assessment Rate
SelfPayRate.find_or_create_by!(
  session_type: "intake",
  effective_date: effective_date
) do |rate|
  rate.base_rate = 150.00
  rate.end_date = nil # Ongoing
  rate.sliding_scale_available = true
  rate.package_pricing_available = false # Not applicable for intake
  rate.description = "Initial intake assessment (90 minutes)"
  rate.metadata = {
    sliding_scale_tiers: [
      { income_range: "0-25000", discount_percent: 50 },
      { income_range: "25001-50000", discount_percent: 30 },
      { income_range: "50001-75000", discount_percent: 20 },
      { income_range: "75001-100000", discount_percent: 10 }
    ]
  }
end

# Create expired rate for testing effective date filtering
expired_rate_date = Date.parse("2023-01-01")
SelfPayRate.find_or_create_by!(
  session_type: "individual_therapy",
  effective_date: expired_rate_date
) do |rate|
  rate.base_rate = 70.00
  rate.end_date = Date.parse("2023-12-31") # Expired
  rate.sliding_scale_available = false
  rate.package_pricing_available = false
  rate.description = "Individual therapy session (50 minutes) - EXPIRED RATE"
  rate.metadata = {}
end

puts "Self-pay rates seeded successfully!"
puts "  - Individual Therapy: $75/session"
puts "  - Family Therapy: $100/session"
puts "  - Intake Assessment: $150/session"
puts "  - All rates include sliding scale and package options"
