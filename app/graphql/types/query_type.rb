# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    include Concerns::CurrentSession
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
  end
end
