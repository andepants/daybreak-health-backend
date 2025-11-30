# frozen_string_literal: true

module Types
  # GraphQL type for Appointment model
  #
  # Represents booked appointments with therapists
  class AppointmentType < Types::BaseObject
    description 'Appointment information'

    field :id, ID, null: false, description: 'Unique identifier'
    field :therapist, Types::TherapistType, null: false, description: 'Therapist for this appointment'
    field :onboarding_session_id, ID, null: false, description: 'Associated onboarding session ID'
    field :scheduled_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Scheduled date and time'
    field :duration_minutes, Integer, null: false, description: 'Duration in minutes'
    field :status, String, null: false, description: 'Appointment status (scheduled, confirmed, cancelled, completed, no_show)'
    field :confirmation_number, String, null: false, description: 'Confirmation number for appointment'
    field :confirmed_at, GraphQL::Types::ISO8601DateTime, null: true, description: 'When appointment was confirmed'
    field :cancelled_at, GraphQL::Types::ISO8601DateTime, null: true, description: 'When appointment was cancelled'
    field :cancellation_reason, String, null: true, description: 'Reason for cancellation'
    field :location_type, String, null: false, description: 'Location type (virtual or in_person)'
    field :virtual_link, String, null: true, description: 'Virtual meeting link for online appointments'
    field :cancellable, Boolean, null: false, description: 'Whether appointment can be cancelled'
    field :reschedulable, Boolean, null: false, description: 'Whether appointment can be rescheduled'
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When appointment was created'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When appointment was last updated'

    def confirmation_number
      object.confirmation_number
    end

    def cancellable
      object.cancellable?
    end

    def reschedulable
      object.reschedulable?
    end
  end
end
