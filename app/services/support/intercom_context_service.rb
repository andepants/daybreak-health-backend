# frozen_string_literal: true

module Support
  # Intercom context generation service for support agents
  #
  # Generates PHI-safe onboarding context data to help support agents
  # assist parents without asking repetitive questions. All data is
  # sanitized to ensure no PHI is transmitted to Intercom.
  #
  # HIPAA Compliance:
  # - PHI-SAFE: Only session IDs, first names, ages, and status enums
  # - PHI-PROHIBITED: No last names, DOB, emails, phones, addresses, SSN, member IDs
  # - All fields validated to prevent PHI leakage
  #
  # Context Attributes:
  # - session_id: CUID identifier
  # - onboarding_phase: Status enum (started, in_progress, insurance_pending, etc.)
  # - parent_first_name: First name only (no last name)
  # - child_age: Calculated age (not DOB)
  # - insurance_status: Status enum (pending, verified, self_pay)
  # - has_errors: Boolean flag
  # - error_type: Error category if applicable
  # - admin_link: Deep link to admin session view
  #
  # Example usage:
  #   service = Support::IntercomContextService.new(session_id: 'sess_abc123')
  #   context = service.call
  #   # => {
  #   #   session_id: 'sess_abc123',
  #   #   onboarding_phase: 'insurance_pending',
  #   #   parent_first_name: 'Jane',
  #   #   child_age: 12,
  #   #   insurance_status: 'pending',
  #   #   has_errors: false,
  #   #   error_type: nil,
  #   #   admin_link: 'https://admin.daybreak.com/sessions/sess_abc123'
  #   # }
  class IntercomContextService < BaseService
    attr_reader :session_id

    # Initialize the Intercom context service
    #
    # @param session_id [String] The onboarding session ID
    # @raise [ArgumentError] If session_id is blank
    def initialize(session_id:)
      raise ArgumentError, 'session_id cannot be blank' if session_id.blank?

      @session_id = session_id
    end

    # Generate Intercom context payload
    #
    # Returns PHI-safe context data for support agents.
    # All data is sanitized to ensure HIPAA compliance.
    #
    # @return [Hash] Context payload
    #   - session_id [String] Session CUID
    #   - onboarding_phase [String] Current status enum
    #   - parent_first_name [String, nil] Parent's first name only
    #   - child_age [Integer, nil] Child's age (not DOB)
    #   - insurance_status [String, nil] Insurance verification status
    #   - has_errors [Boolean] Whether session has errors
    #   - error_type [String, nil] Error category if applicable
    #   - admin_link [String] Deep link to admin session view
    #
    # @raise [ActiveRecord::RecordNotFound] If session not found
    #
    # @example
    #   service = Support::IntercomContextService.new(session_id: 'sess_123')
    #   context = service.call
    def call
      session = find_session

      {
        session_id: session.id,
        onboarding_phase: extract_onboarding_phase(session),
        parent_first_name: extract_parent_first_name(session),
        child_age: extract_child_age(session),
        insurance_status: extract_insurance_status(session),
        has_errors: detect_errors?(session),
        error_type: extract_error_type(session),
        admin_link: generate_admin_link(session)
      }
    end

    # Class method convenience wrapper
    #
    # @param session_id [String] The onboarding session ID
    # @return [Hash] Context payload
    #
    # @example
    #   Support::IntercomContextService.call(session_id: 'sess_123')
    def self.call(session_id:)
      new(session_id: session_id).call
    end

    private

    # Find the onboarding session
    #
    # @return [OnboardingSession] The session record
    # @raise [ActiveRecord::RecordNotFound] If session not found
    def find_session
      OnboardingSession.includes(:parent, :child, :insurance).find(session_id)
    end

    # Extract onboarding phase from session status
    #
    # PHI-SAFE: Status is an enum value, not PHI
    #
    # @param session [OnboardingSession] The session
    # @return [String] Status enum as string
    def extract_onboarding_phase(session)
      session.status
    end

    # Extract parent's first name (PHI-safe, no last name)
    #
    # PHI-SAFE: First name only, no full name or identifying info
    #
    # @param session [OnboardingSession] The session
    # @return [String, nil] First name or nil if not available
    def extract_parent_first_name(session)
      return nil unless session.parent

      # Decrypt first_name from encrypted field
      # Only first name, NEVER include last name
      session.parent.first_name
    end

    # Extract child's age (PHI-safe, not DOB)
    #
    # PHI-SAFE: Age is calculated, DOB is NOT transmitted
    #
    # @param session [OnboardingSession] The session
    # @return [Integer, nil] Age in years or nil if not available
    def extract_child_age(session)
      return nil unless session.child

      # Use Child model's age calculation method
      # This returns age in years, NOT the actual DOB
      session.child.age
    end

    # Extract insurance verification status
    #
    # PHI-SAFE: Status enum only, no policy numbers or member IDs
    #
    # @param session [OnboardingSession] The session
    # @return [String, nil] Insurance status enum or nil
    def extract_insurance_status(session)
      return nil unless session.insurance

      # Return status enum only (pending, verified, failed, self_pay, etc.)
      # NEVER include: policy_number, member_id, group_number, subscriber info
      session.insurance.verification_status
    end

    # Detect if session has any error states
    #
    # Checks for:
    # - Expired session
    # - Abandoned session
    # - Insurance verification failed
    # - OCR extraction failed
    # - Manual review required
    #
    # @param session [OnboardingSession] The session
    # @return [Boolean] True if session has errors or blockers
    def detect_errors?(session)
      return true if session.expired?
      return true if session.abandoned?
      return true if insurance_has_errors?(session)

      false
    end

    # Extract error type/category
    #
    # PHI-SAFE: Error category only, no detailed messages with PHI
    #
    # @param session [OnboardingSession] The session
    # @return [String, nil] Error type or nil if no errors
    def extract_error_type(session)
      return 'session_expired' if session.expired?
      return 'session_abandoned' if session.abandoned?

      if session.insurance
        insurance = session.insurance

        return 'ocr_extraction_failed' if insurance.ocr_error.present?
        return 'eligibility_verification_failed' if insurance.eligibility_failed?
        return 'eligibility_needs_review' if insurance.needs_eligibility_review?
        return 'missing_required_fields' if insurance_missing_fields?(insurance)
      end

      nil
    end

    # Check if insurance has error states
    #
    # @param session [OnboardingSession] The session
    # @return [Boolean] True if insurance has errors
    def insurance_has_errors?(session)
      return false unless session.insurance

      insurance = session.insurance
      insurance.ocr_error.present? ||
        insurance.eligibility_failed? ||
        insurance.needs_eligibility_review? ||
        insurance_missing_fields?(insurance)
    end

    # Check if insurance is missing required fields
    #
    # @param insurance [Insurance] The insurance record
    # @return [Boolean] True if missing required fields
    def insurance_missing_fields?(insurance)
      # Check if insurance is in a state where it should have data but doesn't
      return false if insurance.pending? || insurance.in_progress?

      # After OCR or manual entry, these fields should be present
      insurance.payer_name.blank? || insurance.member_id.blank?
    end

    # Generate admin deep link
    #
    # PHI-SAFE: Only session ID in URL, no PHI
    #
    # Format: {ADMIN_URL}/sessions/{session_id}
    #
    # @param session [OnboardingSession] The session
    # @return [String] Admin dashboard URL
    def generate_admin_link(session)
      admin_base_url = ENV['ADMIN_DASHBOARD_URL'] || 'https://admin.daybreak.health'
      "#{admin_base_url}/sessions/#{session.id}"
    end
  end
end
