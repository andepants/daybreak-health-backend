# frozen_string_literal: true

module Scheduling
  class AvailabilityService
    # Calculate available appointment slots for a therapist within a date range
    #
    # @param therapist_id [String] UUID of the therapist
    # @param start_date [Date] Start date of the range
    # @param end_date [Date] End date of the range
    # @param timezone [String] IANA timezone for slot calculation (default: 'UTC')
    # @return [Array<Hash>] Array of slot hashes with :start_time, :end_time, :therapist_id
    def self.available_slots(therapist_id:, start_date:, end_date:, timezone: 'UTC')
      therapist = Therapist.find(therapist_id)
      slot_duration = therapist.total_slot_duration

      # Get all time-offs for this therapist in the date range
      time_offs = therapist.therapist_time_offs.for_date_range(start_date, end_date)

      slots = []

      # Iterate through each date in the range
      (start_date..end_date).each do |date|
        # Skip if this date is blocked by time-off
        next if date_blocked_by_time_off?(date, time_offs)

        # Get recurring availabilities for this day of week
        day_of_week = date.wday
        availabilities = therapist.therapist_availabilities
                                   .repeating
                                   .for_day_of_week(day_of_week)

        # Generate slots for each availability window
        availabilities.each do |availability|
          slots.concat(
            generate_slots_for_availability(
              availability,
              date,
              slot_duration,
              timezone
            )
          )
        end
      end

      slots
    end

    # Check if a date is blocked by any time-off period
    #
    # @param date [Date] The date to check
    # @param time_offs [ActiveRecord::Relation] Collection of TherapistTimeOff records
    # @return [Boolean] true if date is blocked
    def self.date_blocked_by_time_off?(date, time_offs)
      time_offs.any? { |time_off| time_off.covers_date?(date) }
    end

    # Generate individual time slots within an availability window
    #
    # @param availability [TherapistAvailability] The availability window
    # @param date [Date] The specific date
    # @param slot_duration [Integer] Duration in minutes (appointment + buffer)
    # @param output_timezone [String] Timezone for output
    # @return [Array<Hash>] Array of slot hashes
    def self.generate_slots_for_availability(availability, date, slot_duration, output_timezone)
      slots = []

      # Parse times in the availability's timezone
      tz = ActiveSupport::TimeZone[availability.timezone]
      start_datetime = tz.parse("#{date} #{availability.start_time}")
      end_datetime = tz.parse("#{date} #{availability.end_time}")

      current_time = start_datetime

      # Generate slots that fit within the availability window
      while current_time + slot_duration.minutes <= end_datetime
        slot_end = current_time + slot_duration.minutes

        # Convert to output timezone
        output_tz = ActiveSupport::TimeZone[output_timezone]
        slots << {
          start_time: current_time.in_time_zone(output_tz),
          end_time: slot_end.in_time_zone(output_tz),
          therapist_id: availability.therapist_id,
          duration_minutes: slot_duration
        }

        current_time = slot_end
      end

      slots
    end

    private_class_method :generate_slots_for_availability, :date_blocked_by_time_off?
  end
end
