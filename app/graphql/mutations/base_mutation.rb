# frozen_string_literal: true

module Mutations
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    include GraphqlConcerns::CurrentSession

    argument_class Types::BaseArgument
    field_class Types::BaseField
    input_object_class Types::BaseInputObject
    object_class Types::BaseObject

    # Helper method to authorize with Pundit
    #
    # @param record [ActiveRecord::Base] Record to authorize
    # @param query [Symbol] Policy method to call
    # @raise [Pundit::NotAuthorizedError] If authorization fails
    def authorize(record, query)
      policy = Pundit.policy(current_user, record)
      raise Pundit::NotAuthorizedError unless policy.public_send(query)

      true
    end
  end
end
