# frozen_string_literal: true

# Onboarding phase configuration
# Defines the phases in the onboarding flow with their required fields and baseline durations
#
# Each phase includes:
# - required_fields: Number of required fields to complete the phase (nil = variable)
# - baseline_minutes: Average time in minutes for completing the phase
#
# These baselines are used for time estimation and can be adjusted based on actual data.
# Admin UI for updating these values is planned for Epic 7 Story 7.5 (FR41).
ONBOARDING_PHASES = {
  welcome: {
    required_fields: 0,
    baseline_minutes: 1,
    description: 'Initial welcome and introduction'
  },
  parent_info: {
    required_fields: 6, # firstName, lastName, email, phone, relationship, isGuardian
    baseline_minutes: 2,
    description: 'Parent/guardian information collection'
  },
  child_info: {
    required_fields: 4, # firstName, lastName, dateOfBirth, concerns
    baseline_minutes: 3,
    description: 'Child information collection'
  },
  concerns: {
    required_fields: 1, # primaryConcerns
    baseline_minutes: 2,
    description: 'Primary concerns discussion'
  },
  insurance: {
    required_fields: 3, # payerName, memberId, groupNumber OR selfPay
    baseline_minutes: 4,
    description: 'Insurance verification or self-pay selection'
  },
  assessment: {
    required_fields: nil, # Variable based on branching logic
    baseline_minutes: 5,
    description: 'Clinical assessment questionnaire'
  }
}.freeze

# Phase order for progress tracking
ONBOARDING_PHASE_ORDER = %i[welcome parent_info child_info concerns insurance assessment].freeze

# Helper to get total required fields (excluding variable phases)
ONBOARDING_TOTAL_REQUIRED_FIELDS = ONBOARDING_PHASES.values
  .map { |phase| phase[:required_fields] }
  .compact
  .sum
  .freeze
