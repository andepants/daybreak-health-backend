# frozen_string_literal: true

module Types
  # GraphQL type for Intercom context payload
  #
  # Provides PHI-safe onboarding context for support agents.
  # All fields are sanitized to ensure HIPAA compliance.
  #
  # HIPAA Compliance:
  # - PHI-SAFE: session_id (CUID), onboarding_phase (enum), parent_first_name,
  #             child_age (integer), insurance_status (enum), error flags
  # - PHI-PROHIBITED: No last names, DOB, emails, phones, addresses, SSN, member IDs
  #
  # Used by: generateIntercomContext query
  class IntercomContextType < Types::BaseObject
    description 'PHI-safe onboarding context for Intercom support agents'

    field :session_id, String, null: false,
          description: 'Onboarding session CUID identifier'

    field :onboarding_phase, String, null: false,
          description: 'Current onboarding status (started, in_progress, insurance_pending, etc.)'

    field :parent_first_name, String, null: true,
          description: 'Parent first name only (no last name, PHI-safe)'

    field :child_age, Integer, null: true,
          description: 'Child age in years (calculated, not DOB, PHI-safe)'

    field :insurance_status, String, null: true,
          description: 'Insurance verification status enum (pending, verified, failed, self_pay)'

    field :has_errors, Boolean, null: false,
          description: 'Whether session has errors or blockers'

    field :error_type, String, null: true,
          description: 'Error category if has_errors is true (session_expired, ocr_failed, etc.)'

    field :admin_link, String, null: false,
          description: 'Deep link to admin dashboard session view'
  end
end
