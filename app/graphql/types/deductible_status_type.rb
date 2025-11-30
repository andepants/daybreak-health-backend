# frozen_string_literal: true

module Types
  # GraphQL type for detailed deductible and out-of-pocket tracking
  #
  # Provides comprehensive information about a patient's deductible progress,
  # out-of-pocket maximum status, and projections for healthcare spending.
  # Used to help parents understand their financial responsibility and plan expenses.
  #
  # Story 6.4: Deductible & Out-of-Pocket Tracking
  # AC1: Show deductible amount met and remaining
  # AC2: Show OOP max spent and remaining
  # AC3: Distinguish family vs individual plans
  # AC4: Project sessions until deductible met
  # AC5: Provide visual progress indicators and plan year reset date
  #
  class DeductibleStatusType < Types::BaseObject
    description "Detailed deductible and out-of-pocket tracking information"

    # Core deductible fields (backward compatible with existing usage)
    field :amount, Float, null: false,
          description: "Total annual deductible amount in USD"

    field :met, Float, null: false,
          description: "Amount of deductible met so far this year in USD"

    field :remaining, Float, null: false,
          description: "Amount of deductible remaining to be met in USD"

    field :is_met, Boolean, null: false,
          description: "Whether the deductible has been fully met"

    # Story 6.4: Enhanced deductible tracking fields
    field :deductible_amount, Float, null: true,
          description: "Total annual deductible amount in dollars (alias for 'amount')"

    field :deductible_met, Float, null: true,
          description: "Amount of deductible already met this plan year (alias for 'met')"

    field :deductible_remaining, Float, null: true,
          description: "Amount of deductible still owed before insurance covers services (alias for 'remaining')"

    # Story 6.4: Out-of-pocket maximum tracking (AC2)
    field :oop_max_amount, Float, null: true,
          description: "Total annual out-of-pocket maximum in dollars"

    field :oop_met, Float, null: true,
          description: "Amount already spent toward out-of-pocket maximum"

    field :oop_remaining, Float, null: true,
          description: "Amount remaining before out-of-pocket maximum is reached"

    # Story 6.4: Plan type distinction (AC3)
    field :is_family_plan, Boolean, null: true,
          description: "Whether this is a family plan (true) or individual plan (false)"

    # Story 6.4: Plan year tracking (AC5)
    field :year_reset_date, GraphQL::Types::ISO8601DateTime, null: true,
          description: "Date when deductible and OOP max will reset for new plan year"

    # Story 6.4: Progress indicators (AC5)
    field :progress_percentage, Integer, null: true,
          description: "Percentage of deductible met (0-100) for visual progress indicator"

    field :oop_progress_percentage, Integer, null: true,
          description: "Percentage of out-of-pocket maximum met (0-100)"

    # Story 6.4: Session projection (AC4)
    field :sessions_until_deductible_met, Integer, null: true,
          description: "Estimated number of therapy sessions until deductible is fully met"

    # Story 6.4: Data provenance (AC6)
    field :data_source, String, null: true,
          description: "Source of deductible data: 'eligibility_api', 'manual_override', or 'cached'"

    field :last_updated_at, GraphQL::Types::ISO8601DateTime, null: true,
          description: "When deductible data was last updated from eligibility check"
  end
end
