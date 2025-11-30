# frozen_string_literal: true

module Types
  # GraphQL type for Child model
  #
  # Represents the child information in an onboarding session.
  # PHI fields (first_name, last_name, date_of_birth, primary_concerns) are encrypted at rest.
  class ChildType < Types::BaseObject
    description 'Child information'

    field :id, ID, null: false, description: 'Unique identifier'
    field :first_name, String, null: false, description: 'Child first name (encrypted)', camelize: false
    field :last_name, String, null: false, description: 'Child last name (encrypted)', camelize: false
    field :date_of_birth, String, null: false, description: 'Child date of birth in ISO 8601 format (encrypted)', camelize: false
    field :age, Integer, null: true, description: 'Child age calculated from date of birth'
    field :gender, String, null: true, description: 'Child gender (optional)'
    field :school_name, String, null: true, description: 'Name of child school (optional)', camelize: false
    field :grade, String, null: true, description: 'Child current grade level (optional)'
    field :primary_concerns, String, null: true, description: 'Primary concerns in parent own words (encrypted)', camelize: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When record was created', camelize: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When record was last updated', camelize: false
  end
end
