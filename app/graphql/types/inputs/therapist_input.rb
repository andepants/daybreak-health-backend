# frozen_string_literal: true

module Types
  module Inputs
    # Input type for creating/updating therapist profiles
    # AC 5.1.9: Admin can CRUD therapist profiles via GraphQL
    class TherapistInput < Types::BaseInputObject
      description "Input for creating or updating therapist profiles"

      argument :first_name, String, required: true, description: "Therapist's first name", camelize: false
      argument :last_name, String, required: true, description: "Therapist's last name", camelize: false
      argument :email, String, required: false, description: "Therapist's email address", camelize: false
      argument :phone, String, required: false, description: "Therapist's phone number", camelize: false
      argument :license_type, String, required: false, description: "License type (LCSW, LMFT, LPCC, etc.)", camelize: false
      argument :license_number, String, required: false, description: "License number", camelize: false
      argument :license_state, String, required: false, description: "State where licensed", camelize: false
      argument :license_expiration, GraphQL::Types::ISO8601Date, required: false, description: "License expiration date", camelize: false
      argument :npi_number, String, required: false, description: "National Provider Identifier", camelize: false
      argument :bio, String, required: false, description: "Therapist biography", camelize: false
      argument :photo_url, String, required: false, description: "Profile photo URL", camelize: false
      argument :active, Boolean, required: false, description: "Whether therapist is active", camelize: false
      argument :languages, [String], required: false, description: "Languages spoken (ISO 639-1 codes)", camelize: false
      argument :age_ranges, [String], required: false, description: "Age ranges served (e.g., ['5-12', '13-17'])", camelize: false
      argument :treatment_modalities, [String], required: false, description: "Treatment modalities (CBT, DBT, EMDR, etc.)", camelize: false
      argument :specializations, [String], required: false, description: "Clinical specializations", camelize: false
    end
  end
end
