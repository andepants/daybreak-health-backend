# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    include GraphqlConcerns::CurrentSession
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [Types::NodeType, null: true], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ID], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    # Session queries
    field :session, Types::OnboardingSessionType, null: false, description: "Get session by ID" do
      argument :id, ID, required: true, description: "Session ID"
    end

    field :session_by_recovery_token, resolver: Queries::Sessions::SessionByRecoveryToken

    # Story 3.5: Contact options query
    # AC 3.5.4: Contact options provided to parent
    # AC 3.5.9: Option always visible/accessible
    field :contact_options, Types::ContactOptionsType, null: false,
          description: "Get support contact options for requesting human assistance"

    def contact_options
      ContactOptions.for_parent
    end

    def session(id:)
      # Strip sess_ prefix and convert back to UUID format if needed
      actual_id = if id.start_with?('sess_')
        hex = id.sub('sess_', '')
        # Convert 32-char hex to UUID format: 8-4-4-4-12
        "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
      else
        id
      end

      # Load session by ID
      session = OnboardingSession.find(actual_id)

      # Verify user has access to this session
      # For now, allow access if authenticated (will be enhanced in Story 2.6)
      if current_session && current_session.id == session.id
        session
      else
        raise GraphQL::ExecutionError.new(
          'Session not found or access denied',
          extensions: {
            code: 'UNAUTHENTICATED',
            timestamp: Time.current.iso8601
          }
        )
      end
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError.new(
        'Session not found',
        extensions: {
          code: 'NOT_FOUND',
          timestamp: Time.current.iso8601
        }
      )
    end

    # Story 5.1: Assessment query
    field :assessment, Types::AssessmentType, null: true,
          description: "Get assessment for a session" do
      argument :session_id, ID, required: true, description: "Session ID"
    end

    def assessment(session_id:)
      # Strip sess_ prefix and convert back to UUID format if needed
      actual_id = if session_id.start_with?('sess_')
        hex = session_id.sub('sess_', '')
        "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
      else
        session_id
      end

      session = OnboardingSession.find(actual_id)

      # Verify access
      unless current_session && current_session.id == session.id
        raise GraphQL::ExecutionError.new(
          'Access denied',
          extensions: { code: 'UNAUTHENTICATED' }
        )
      end

      session.assessment
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError.new(
        'Session not found',
        extensions: { code: 'NOT_FOUND' }
      )
    end

    # Story 5.1: Assessment questions query
    field :assessment_questions, [Types::AssessmentQuestionType], null: false,
          description: "Get all assessment questions for a child's age" do
      argument :child_age, Integer, required: true, description: "Child's age in years"
      argument :instrument, String, required: false, description: "Optional: 'phq_a' or 'gad_7'"
    end

    def assessment_questions(child_age:, instrument: nil)
      questions = Assessments::QuestionSets.all_questions(age: child_age)

      result = case instrument&.downcase
               when 'phq_a' then questions[:phq_a]
               when 'gad_7' then questions[:gad_7]
               else questions[:phq_a] + questions[:gad_7]
               end

      result.map do |q|
        {
          id: q[:id],
          item: q[:item],
          text: q[:text],
          domain: q[:domain],
          instrument: q[:id].start_with?('phq') ? 'PHQ-A' : 'GAD-7'
        }
      end
    end

    # Story 6.1: Cost calculation query
    # AC 6.1.1, 6.1.2, 6.1.3: Calculate therapy session costs
    field :calculate_cost, resolver: Queries::CalculateCost

    # Story 6.2: Insurance cost estimation query
    # AC 6.2.1, 6.2.3, 6.2.4, 6.2.5: Estimate costs based on insurance coverage
    field :insurance_cost_estimate, resolver: Queries::InsuranceCostEstimate

    # Story 6.3: Cost comparison query
    # AC 6.3.1-6.3.9: Compare insurance estimates with self-pay rates
    field :cost_comparison, resolver: Queries::CostComparison

    # Story 6.4: Deductible status tracking query
    # AC 6.4.1-6.4.6: Track deductible progress, OOP max, and projections
    field :deductible_status, resolver: Queries::Billing::DeductibleStatus

    # Story 7.1: Intercom widget integration
    # AC 7.1.4: Backend GraphQL endpoint provides Intercom identity verification hash
    # AC 7.1.5: Identity verification enabled to prevent user impersonation
    field :intercom_identity, Types::IntercomIdentityType, null: false,
          description: "Get Intercom identity verification data for secure widget initialization" do
      argument :session_id, ID, required: true, description: "Session ID to generate identity for"
    end

    # Story 7.2: Session context passing
    # AC 7.2.1: Generate PHI-safe context payload for Intercom support agents
    # AC 7.2.2: No PHI transmitted (only IDs, first names, ages, status enums)
    field :generate_intercom_context, Types::IntercomContextType, null: false,
          description: "Generate PHI-safe onboarding context for Intercom support agents" do
      argument :session_id, ID, required: true, description: "Session ID to generate context for"
    end

    def intercom_identity(session_id:)
      # Strip sess_ prefix and convert back to UUID format if needed
      actual_id = normalize_session_id(session_id)

      # Verify session exists
      session = OnboardingSession.find(actual_id)

      # Verify user has access to this session
      unless current_session && current_session.id == session.id
        raise GraphQL::ExecutionError.new(
          'Access denied',
          extensions: {
            code: 'UNAUTHENTICATED',
            timestamp: Time.current.iso8601
          }
        )
      end

      # Generate Intercom identity
      Support::IntercomService.call(session_id: session.id)
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError.new(
        'Session not found',
        extensions: {
          code: 'NOT_FOUND',
          timestamp: Time.current.iso8601
        }
      )
    end

    def generate_intercom_context(session_id:)
      # Strip sess_ prefix and convert back to UUID format if needed
      actual_id = normalize_session_id(session_id)

      # Verify session exists
      session = OnboardingSession.find(actual_id)

      # Verify user has access to this session
      unless current_session && current_session.id == session.id
        raise GraphQL::ExecutionError.new(
          'Access denied',
          extensions: {
            code: 'UNAUTHENTICATED',
            timestamp: Time.current.iso8601
          }
        )
      end

      # Generate Intercom context payload
      Support::IntercomContextService.call(session_id: session.id)
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError.new(
        'Session not found',
        extensions: {
          code: 'NOT_FOUND',
          timestamp: Time.current.iso8601
        }
      )
    end

    # Story 5.1: Therapist queries
    # AC 5.1.9: Admin can CRUD therapist profiles via GraphQL
    field :therapist, Types::TherapistType, null: true,
          description: "Get a single therapist by ID" do
      argument :id, ID, required: true, description: "Therapist ID"
    end

    def therapist(id:)
      therapist = Therapist.find(id)
      # Apply policy scope to ensure proper authorization
      policy_scope = Pundit.policy_scope!(current_user, Therapist)
      policy_scope.find_by(id: therapist.id)
    rescue ActiveRecord::RecordNotFound
      nil
    rescue Pundit::NotAuthorizedError
      nil
    end

    field :therapists, [Types::TherapistType], null: false,
          description: "List therapists with optional filters" do
      argument :active, Boolean, required: false, description: "Filter by active status"
      argument :state, String, required: false, description: "Filter by license state"
      argument :specialization, String, required: false, description: "Filter by specialization"
      argument :insurance_name, String, required: false, description: "Filter by insurance panel name"
    end

    def therapists(active: nil, state: nil, specialization: nil, insurance_name: nil)
      # Apply policy scope to ensure proper authorization
      result = Pundit.policy_scope!(current_user, Therapist)

      # Add eager loading to prevent N+1 queries
      result = result.includes(:therapist_specializations, :therapist_insurance_panels)

      result = result.active if active == true
      result = result.where(active: false) if active == false
      result = result.by_state(state) if state.present?
      result = result.with_specialization(specialization) if specialization.present?

      if insurance_name.present?
        result = result.joins(:therapist_insurance_panels)
                       .where(therapist_insurance_panels: { insurance_name: insurance_name })
                       .distinct
      end

      result
    rescue Pundit::NotAuthorizedError
      # If unauthorized, return empty array rather than error
      []
    end

    # Story 5.2: Available slots query
    # AC 5.2.6: Query available appointment slots for a therapist
    field :available_slots, [Types::TimeSlotType], null: false,
          description: "Get available appointment slots for a therapist within a date range" do
      argument :therapist_id, ID, required: true, description: "Therapist ID"
      argument :start_date, GraphQL::Types::ISO8601Date, required: true, description: "Start date of the range"
      argument :end_date, GraphQL::Types::ISO8601Date, required: true, description: "End date of the range"
      argument :timezone, String, required: false, default_value: 'UTC', description: "Timezone for results (default: UTC)"
    end

    def available_slots(therapist_id:, start_date:, end_date:, timezone: 'UTC')
      # Validate date range
      if start_date > end_date
        raise GraphQL::ExecutionError.new(
          'Start date must be before or equal to end date',
          extensions: { code: 'INVALID_INPUT' }
        )
      end

      # Calculate and return available slots
      slots = Scheduling::AvailabilityService.available_slots(
        therapist_id: therapist_id,
        start_date: start_date,
        end_date: end_date,
        timezone: timezone
      )

      # Convert hash objects to OpenStruct for GraphQL compatibility
      slots.map { |slot| OpenStruct.new(slot) }
    rescue ActiveRecord::RecordNotFound => e
      raise GraphQL::ExecutionError.new(
        "Therapist not found: #{e.message}",
        extensions: { code: 'NOT_FOUND' }
      )
    rescue ArgumentError => e
      raise GraphQL::ExecutionError.new(
        "Invalid timezone: #{e.message}",
        extensions: { code: 'INVALID_INPUT' }
      )
    end

    # Story 5.4: Therapist matching recommendations query
    # AC 5.4.1, 5.4.10, 5.4.13: AI-matched therapist recommendations
    field :therapist_matches, resolver: Queries::TherapistMatches

    # Story 5.1: Matched therapists query (frontend-friendly format)
    # Returns wrapped results with therapists array, totalCount, and matchingCriteria
    field :matched_therapists, Types::TherapistMatchResultsWrapperType, null: true,
          description: "Get matched therapists for a session (frontend-friendly format)" do
      argument :session_id, ID, required: true, description: "Session ID"
    end

    def matched_therapists(session_id:)
      # Load and authorize session
      actual_id = normalize_session_id(session_id)
      session = OnboardingSession.find(actual_id)

      # Verify user has access
      unless current_session && current_session.id == session.id
        raise GraphQL::ExecutionError.new(
          'Access denied',
          extensions: {
            code: 'UNAUTHENTICATED',
            timestamp: Time.current.iso8601
          }
        )
      end

      # Validate session is ready for matching
      unless session.child && session.insurance && session.assessment&.status == "complete"
        raise GraphQL::ExecutionError.new(
          'Session must have complete child, insurance, and assessment data',
          extensions: {
            code: 'VALIDATION_ERROR',
            timestamp: Time.current.iso8601
          }
        )
      end

      # Execute matching service
      matching_service = Scheduling::MatchingService.new(session_id: session.id)
      matches = matching_service.match

      # Return wrapper structure
      {
        matches: matches,
        criteria_description: nil # Will use default in type
      }
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError.new(
        'Session not found',
        extensions: {
          code: 'NOT_FOUND',
          timestamp: Time.current.iso8601
        }
      )
    end

    # Story 7.3: Support request tracking
    # AC 7.3.4: Query support requests for a session
    field :support_requests, [Types::SupportRequestType], null: false,
          description: "Get support requests for a session" do
      argument :session_id, ID, required: true, description: "Session ID"
    end

    def support_requests(session_id:)
      # Strip sess_ prefix and convert back to UUID format if needed
      actual_id = if session_id.start_with?('sess_')
        hex = session_id.sub('sess_', '')
        "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
      else
        session_id
      end

      # Load session by ID
      session = OnboardingSession.find(actual_id)

      # Apply authorization policy
      # Only session owner or admin can view support requests
      unless current_user && (current_user[:session_id] == session.id || current_user[:role] == 'admin')
        raise GraphQL::ExecutionError.new(
          'Access denied',
          extensions: {
            code: 'UNAUTHENTICATED',
            timestamp: Time.current.iso8601
          }
        )
      end

      # Return support requests for the session
      session.support_requests.recent
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError.new(
        'Session not found',
        extensions: {
          code: 'NOT_FOUND',
          timestamp: Time.current.iso8601
        }
      )
    end

    # Story 7.3: Support analytics query
    # AC 7.3.5: Analytics for support hotspots (admin only)
    field :support_analytics, Types::SupportAnalyticsType, null: false,
          description: "Get support request analytics (admin only)" do
      argument :start_date, GraphQL::Types::ISO8601Date, required: false, description: "Optional start date filter"
      argument :end_date, GraphQL::Types::ISO8601Date, required: false, description: "Optional end date filter"
    end

    # Story 6.5: Payment plan options query
    # AC 6.5.1, 6.5.2, 6.5.3, 6.5.4: Calculate payment plan options
    field :payment_plan_options, [Types::PaymentPlanOptionType], null: false,
          description: "Get payment plan options for estimated cost" do
      argument :session_id, ID, required: true, description: "Session ID"
      argument :estimated_cost, Float, required: true, description: "Estimated total cost in USD"
    end

    # Story 6.5: Financial assistance information query
    # AC 6.5.5, 6.5.6: Display financial assistance program information
    field :financial_assistance_info, Types::FinancialAssistanceType, null: false,
          description: "Get financial assistance program information"

    def support_analytics(start_date: nil, end_date: nil)
      # Only admins can access analytics
      unless current_user && current_user[:role] == 'admin'
        raise GraphQL::ExecutionError.new(
          'Access denied - admin only',
          extensions: {
            code: 'FORBIDDEN',
            timestamp: Time.current.iso8601
          }
        )
      end

      # Return analytics data
      Analytics::SupportAnalyticsService.call(
        start_date: start_date,
        end_date: end_date
      )
    end

    def payment_plan_options(session_id:, estimated_cost:)
      # Normalize session ID
      actual_id = normalize_session_id(session_id)

      # Verify session exists
      session = OnboardingSession.find(actual_id)

      # Verify user has access to this session
      unless current_session && current_session.id == session.id
        raise GraphQL::ExecutionError.new(
          'Access denied',
          extensions: {
            code: 'UNAUTHENTICATED',
            timestamp: Time.current.iso8601
          }
        )
      end

      # Calculate payment plan options
      Billing::PaymentPlanService.call(total_amount: estimated_cost)
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError.new(
        'Session not found',
        extensions: {
          code: 'NOT_FOUND',
          timestamp: Time.current.iso8601
        }
      )
    rescue ArgumentError => e
      raise GraphQL::ExecutionError.new(
        "Invalid input: #{e.message}",
        extensions: {
          code: 'INVALID_INPUT',
          timestamp: Time.current.iso8601
        }
      )
    end

    def financial_assistance_info
      # Return financial assistance configuration as hash for FinancialAssistanceType
      {}
    end

    private

    # Normalize session ID by converting sess_ prefix to UUID format
    #
    # @param session_id [String] Session ID (either UUID or sess_ prefixed)
    # @return [String] UUID formatted session ID
    def normalize_session_id(session_id)
      if session_id.start_with?('sess_')
        hex = session_id.sub('sess_', '')
        # Convert 32-char hex to UUID format: 8-4-4-4-12
        "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
      else
        session_id
      end
    end
  end
end
