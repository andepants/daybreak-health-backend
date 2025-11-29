# frozen_string_literal: true

module GraphQLHelper
  def execute_graphql(query, variables: {}, context: {})
    DaybreakHealthBackendSchema.execute(
      query,
      variables: variables,
      context: context
    ).to_h
  end
end

RSpec.configure do |config|
  config.include GraphQLHelper, type: :graphql
  config.include GraphQLHelper, type: :integration
end
