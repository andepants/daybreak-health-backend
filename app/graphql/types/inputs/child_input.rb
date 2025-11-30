# frozen_string_literal: true

module Types
  module Inputs
    # Input type for submitting child information
    # AC 3.7.1, 3.7.2: Collect child demographics and school information
    class ChildInput < Types::BaseInputObject
      description "Input for submitting child information"

      argument :first_name, String, required: true, description: "Child's first name", camelize: false
      argument :last_name, String, required: true, description: "Child's last name", camelize: false
      argument :date_of_birth, String, required: true, description: "Child's date of birth in ISO 8601 format (YYYY-MM-DD)", camelize: false
      argument :gender, String, required: false, description: "Child's gender (optional)", camelize: false
      argument :school_name, String, required: false, description: "Name of child's school (optional)", camelize: false
      argument :grade, String, required: false, description: "Child's current grade level (optional)", camelize: false
      argument :primary_concerns, String, required: false, description: "Primary concerns in parent's own words (optional)", camelize: false
    end
  end
end
