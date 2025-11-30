# frozen_string_literal: true

module Types
  # GraphQL type for Therapist model
  #
  # Represents therapist profiles including credentials, specializations, and insurance panels.
  class TherapistType < Types::BaseObject
    description 'Therapist profile information'

    field :id, ID, null: false, description: 'Unique identifier'
    field :first_name, String, null: false, description: 'Therapist first name'
    field :last_name, String, null: false, description: 'Therapist last name'
    field :full_name, String, null: false, description: 'Full name (computed)'
    field :email, String, null: true, description: 'Therapist email address'
    field :phone, String, null: true, description: 'Therapist phone number'
    field :license_type, String, null: true, description: 'License type (LCSW, LMFT, LPCC, etc.)'
    field :license_number, String, null: true, description: 'License number'
    field :license_state, String, null: true, description: 'State where licensed'
    field :license_expiration, GraphQL::Types::ISO8601Date, null: true, description: 'License expiration date'
    field :npi_number, String, null: true, description: 'National Provider Identifier'
    field :bio, String, null: true, description: 'Therapist biography'
    field :photo_url, String, null: true, description: 'Profile photo URL'
    field :active, Boolean, null: false, description: 'Whether therapist is active'
    field :languages, [String], null: false, description: 'Languages spoken (ISO 639-1 codes)'
    field :age_ranges, [String], null: false, description: 'Age ranges served (e.g., 5-12, 13-17)'
    field :treatment_modalities, [String], null: false, description: 'Treatment modalities (CBT, DBT, EMDR, etc.)'
    field :specializations, [String], null: false, description: 'Clinical specializations'
    field :insurance_panels, [Types::InsurancePanelType], null: false, description: 'Insurance panels accepted'
    field :appointment_duration_minutes, Integer, null: false, description: 'Default appointment duration in minutes'
    field :buffer_time_minutes, Integer, null: false, description: 'Buffer time between appointments in minutes'
    field :availabilities, [Types::TherapistAvailabilityType], null: false, description: 'Weekly recurring availability slots'
    field :time_offs, [Types::TherapistTimeOffType], null: false, description: 'Time-off periods (vacations, blocked times)'
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When record was created'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When record was last updated'

    def full_name
      object.full_name
    end

    def specializations
      object.specializations
    end
  end
end
