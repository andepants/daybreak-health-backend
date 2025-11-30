# frozen_string_literal: true

module Types
  module Inputs
    class ParentInput < Types::BaseInputObject
      description "Input for submitting parent/guardian information"

      argument :first_name, String, required: true, description: "Parent's first name"
      argument :last_name, String, required: true, description: "Parent's last name"
      argument :email, String, required: true, description: "Parent's email address (RFC 5322 format)"
      argument :phone, String, required: true, description: "Parent's phone number (E.164 format, e.g., +15551234567)"
      argument :relationship, String, required: true, description: "Relationship to child: parent, guardian, grandparent, foster_parent, or other"
      argument :is_guardian, Boolean, required: true, description: "Whether this person is the legal guardian"
    end
  end
end
