# frozen_string_literal: true

require "ostruct"

module Queries
  # Resolver for costComparison query
  #
  # Returns comprehensive cost comparison between insurance and self-pay options
  class CostComparison < Queries::BaseQuery
    include GraphqlConcerns::CurrentSession
    include GraphqlConcerns::SessionIdParser

    description "Get cost comparison between insurance and self-pay for a session"

    argument :session_id, ID, required: true, description: "Session ID"

    type Types::CostComparisonType, null: false

    def resolve(session_id:)
      # Parse session ID to UUID format
      actual_id = parse_session_id(session_id)

      # Load session with eager loading to prevent N+1 queries
      session = OnboardingSession.includes(:insurance, :child).find(actual_id)

      # Verify authorization using timing-safe comparison
      unless current_session && secure_compare(current_session.id.to_s, session.id.to_s)
        raise GraphQL::ExecutionError.new(
          "Access denied",
          extensions: {
            code: "UNAUTHENTICATED",
            timestamp: Time.current.iso8601
          }
        )
      end

      # Calculate comparison
      result = ::Billing::CostComparisonService.call(session.id)

      # Return as OpenStruct for GraphQL compatibility
      ::OpenStruct.new(result)
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError.new(
        "Session not found",
        extensions: {
          code: "NOT_FOUND",
          timestamp: Time.current.iso8601
        }
      )
    end

    private

    # Constant-time string comparison to prevent timing attacks
    #
    # @param a [String] First string
    # @param b [String] Second string
    # @return [Boolean] True if strings match
    def secure_compare(a, b)
      return false if a.nil? || b.nil?
      return false unless a.bytesize == b.bytesize

      l = a.unpack "C#{a.bytesize}"

      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res.zero?
    end
  end
end
