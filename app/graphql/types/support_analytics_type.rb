# frozen_string_literal: true

module Types
  # GraphQL type for Support Analytics
  # Story 7.3: Support Request Tracking
  #
  # Provides analytics on support request patterns for admin users
  #
  class SupportAnalyticsType < Types::BaseObject
    field :total_requests, Integer, null: false, description: 'Total number of support requests'
    field :sessions_with_support, Integer, null: false, description: 'Number of unique sessions that contacted support'
    field :resolution_rate, Float, null: false, description: 'Percentage of resolved requests (0-100)'
    field :requests_by_source, GraphQL::Types::JSON, null: false, description: 'Support requests grouped by source widget location'
    field :requests_by_session_status, GraphQL::Types::JSON, null: false, description: 'Support requests grouped by onboarding session status'
    field :average_resolution_time, Float, null: true, description: 'Average time to resolution in hours'
  end
end
