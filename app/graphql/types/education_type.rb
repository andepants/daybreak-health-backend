# frozen_string_literal: true

module Types
  # GraphQL type for education information
  #
  # Represents educational credentials for therapists
  class EducationType < Types::BaseObject
    description "Education and degree information"

    field :degree, String, null: false,
          description: "Degree name (e.g., 'Master of Science in Clinical Psychology')"

    field :institution, String, null: false,
          description: "Educational institution name"

    field :year, Integer, null: true,
          description: "Year degree was obtained"
  end
end
