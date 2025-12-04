# frozen_string_literal: true

module Types
  module Inputs
    # Input type for a single patient availability time block
    # Used in the submitPatientAvailability mutation
    #
    # @see PatientAvailability model
    class PatientAvailabilityInput < Types::BaseInputObject
      description "Input for a single patient availability time block"

      argument :day_of_week, Integer, required: true,
               description: "Day of week (0=Sunday, 1=Monday, ..., 6=Saturday)",
               camelize: false
      argument :start_time, String, required: true,
               description: "Start time in HH:MM format (e.g., '09:00')",
               camelize: false
      argument :duration_minutes, Integer, required: false, default_value: 60,
               description: "Duration in minutes (default: 60)",
               camelize: false
    end
  end
end
