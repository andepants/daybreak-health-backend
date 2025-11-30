# frozen_string_literal: true

module Types
  # GraphQL type for support contact information
  #
  # Provides appropriate support contact based on error severity.
  # Simple issues get general support; complex issues get insurance specialist.
  class SupportContactType < Types::BaseObject
    description "Support contact information for insurance issues"

    field :type, String, null: false,
          description: "Contact type: 'general' or 'specialist'"

    field :phone, String, null: false,
          description: "Contact phone number"

    field :email, String, null: false,
          description: "Contact email address"

    field :hours, String, null: false,
          description: "Availability hours"
  end
end
