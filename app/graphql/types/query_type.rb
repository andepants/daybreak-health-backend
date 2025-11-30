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
  end
end
