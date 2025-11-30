# frozen_string_literal: true

module Types
  # GraphQL type for progress indicators
  #
  # Represents calculated progress through the onboarding flow
  class ProgressType < Types::BaseObject
    description 'Progress indicators for onboarding session'

    field :percentage, Integer, null: false,
          description: 'Progress percentage (0-100) based on completed required fields'

    field :current_phase, String, null: false,
          description: 'Current phase in the onboarding flow'

    field :completed_phases, [String], null: false,
          description: 'Array of completed phase names'

    field :next_phase, String, null: true,
          description: 'Next phase in the sequence (null if at end)'

    field :estimated_minutes_remaining, Integer, null: false,
          description: 'Estimated minutes to complete remaining phases (adaptive)'
  end
end
