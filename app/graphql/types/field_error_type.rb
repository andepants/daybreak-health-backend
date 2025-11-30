# frozen_string_literal: true

module Types
  # GraphQL type for field-level validation errors
  class FieldErrorType < Types::BaseObject
    description "A field-level validation error"

    field :field, String, null: false, description: "The field name that has the error"
    field :message, String, null: false, description: "The error message"
  end
end
