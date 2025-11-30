# frozen_string_literal: true

module Types
  # GraphQL type for Parent model
  #
  # Represents the parent/guardian information in an onboarding session.
  # PHI fields (email, phone, first_name, last_name) are encrypted at rest.
  class ParentType < Types::BaseObject
    description 'Parent or guardian information'

    field :id, ID, null: false, description: 'Unique identifier'
    field :email, String, null: false, description: 'Parent email address (encrypted)'
    field :phone, String, null: false, description: 'Parent phone number (encrypted)'
    field :first_name, String, null: false, description: 'Parent first name (encrypted)'
    field :last_name, String, null: false, description: 'Parent last name (encrypted)'
    field :relationship, String, null: false, description: 'Relationship to child (parent, guardian, etc.)'
    field :is_guardian, Boolean, null: false, description: 'Whether parent is legal guardian'
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When record was created'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When record was last updated'
  end
end
