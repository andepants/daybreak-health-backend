# frozen_string_literal: true

module Types
  # GraphQL type for Intercom identity verification data
  #
  # Provides all data needed by the frontend to initialize the Intercom widget
  # with secure JWT-based identity verification.
  #
  # HIPAA Compliance:
  # - **CRITICAL**: Session ID is the ONLY identifier passed to Intercom (no PHI)
  # - No names, DOB, email, phone, medical information, or other PHI is transmitted
  # - JWT token prevents impersonation via signed verification
  # - App ID is safe to expose (public configuration)
  # - Requires signed BAA (Business Associate Agreement) with Intercom for production use
  class IntercomIdentityType < Types::BaseObject
    description 'Intercom identity verification data for secure widget initialization'

    field :app_id, String, null: true,
          description: 'Intercom workspace app ID (public, null if not configured)'

    field :user_jwt, String, null: true,
          description: 'Signed JWT token for identity verification (null if disabled)'

    # HIPAA NOTE: user_id is the session ID - the ONLY identifier passed to Intercom.
    # This field must NEVER contain PHI (names, DOB, email, phone, medical data).
    field :user_id, String, null: false,
          description: 'Session ID used as Intercom user identifier (HIPAA: session ID ONLY, no PHI)'

    field :enabled, Boolean, null: false,
          description: 'Whether Intercom integration is enabled'
  end
end
