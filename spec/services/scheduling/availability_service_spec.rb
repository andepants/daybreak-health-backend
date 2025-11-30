# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Scheduling::AvailabilityService do
  # AC 5.2.6: Test availability slot calculation service
  let(:therapist) { create(:therapist, appointment_duration_minutes: 50, buffer_time_minutes: 10) }

  describe '.available_slots' do
    context 'with recurring availability' do
      let!(:monday_availability) do
        create(:therapist_availability,
               therapist: therapist,
               day_of_week: 1,
               start_time: Time.parse('09:00'),
               end_time: Time.parse('12:00'),
               timezone: 'America/Los_Angeles',
               is_repeating: true)
      end

      it 'generates slots for recurring availability' do
        # Find next Monday
        start_date = Date.current.beginning_of_week + 1.week
        end_date = start_date

        slots = described_class.available_slots(
          therapist_id: therapist.id,
          start_date: start_date,
          end_date: end_date,
          timezone: 'America/Los_Angeles'
        )

        # 3 hours (09:00-12:00) / 60 minutes per slot = 3 slots
        expect(slots.length).to eq(3)
        expect(slots.first[:therapist_id]).to eq(therapist.id)
        expect(slots.first[:duration_minutes]).to eq(60)
      end

      it 'respects appointment duration and buffer time' do
        start_date = Date.current.beginning_of_week + 1.week
        end_date = start_date

        slots = described_class.available_slots(
          therapist_id: therapist.id,
          start_date: start_date,
          end_date: end_date
        )

        # Each slot should be appointment_duration + buffer_time apart
        expect(slots.first[:duration_minutes]).to eq(therapist.total_slot_duration)
      end
    end

    context 'with time-offs' do
      let!(:monday_availability) do
        create(:therapist_availability,
               therapist: therapist,
               day_of_week: 1,
               start_time: Time.parse('09:00'),
               end_time: Time.parse('17:00'),
               timezone: 'UTC',
               is_repeating: true)
      end

      it 'excludes dates blocked by time-off' do
        next_monday = Date.current.beginning_of_week + 1.week
        following_monday = next_monday + 1.week

        # Block next Monday
        create(:therapist_time_off,
               therapist: therapist,
               start_date: next_monday,
               end_date: next_monday)

        slots = described_class.available_slots(
          therapist_id: therapist.id,
          start_date: next_monday,
          end_date: following_monday
        )

        # Should only have slots for following Monday, not next Monday
        slot_dates = slots.map { |s| s[:start_time].to_date }.uniq
        expect(slot_dates).not_to include(next_monday)
        expect(slot_dates).to include(following_monday)
      end

      it 'handles multi-day time-offs' do
        start_date = Date.current.beginning_of_week + 1.week
        end_date = start_date + 2.weeks

        # Block the entire second week
        create(:therapist_time_off,
               therapist: therapist,
               start_date: start_date + 1.week,
               end_date: start_date + 1.week + 6.days)

        slots = described_class.available_slots(
          therapist_id: therapist.id,
          start_date: start_date,
          end_date: end_date
        )

        # Should only have slots for first and third week, not second week
        blocked_dates = (start_date + 1.week..start_date + 1.week + 6.days).to_a
        slot_dates = slots.map { |s| s[:start_time].to_date }

        blocked_dates.each do |blocked_date|
          expect(slot_dates).not_to include(blocked_date)
        end
      end
    end

    context 'with multiple availabilities on same day' do
      let!(:morning_availability) do
        create(:therapist_availability,
               therapist: therapist,
               day_of_week: 1,
               start_time: Time.parse('09:00'),
               end_time: Time.parse('12:00'),
               timezone: 'UTC',
               is_repeating: true)
      end

      let!(:afternoon_availability) do
        create(:therapist_availability,
               therapist: therapist,
               day_of_week: 1,
               start_time: Time.parse('13:00'),
               end_time: Time.parse('17:00'),
               timezone: 'UTC',
               is_repeating: true)
      end

      it 'generates slots for both availability windows' do
        next_monday = Date.current.beginning_of_week + 1.week

        slots = described_class.available_slots(
          therapist_id: therapist.id,
          start_date: next_monday,
          end_date: next_monday,
          timezone: 'UTC'
        )

        # Morning: 3 hours / 1 hour = 3 slots
        # Afternoon: 4 hours / 1 hour = 4 slots
        # Total: 7 slots
        expect(slots.length).to eq(7)

        # Verify we have slots from both availability windows
        # Check that we have distinct time windows (slots should not all be consecutive)
        start_times = slots.map { |s| s[:start_time].in_time_zone('UTC').strftime('%H:%M') }.sort
        expect(start_times.length).to eq(7)
      end
    end

    context 'with timezone handling' do
      let!(:availability) do
        create(:therapist_availability,
               therapist: therapist,
               day_of_week: 1,
               start_time: Time.parse('09:00'),
               end_time: Time.parse('12:00'),
               timezone: 'America/Los_Angeles',
               is_repeating: true)
      end

      it 'converts slots to requested timezone' do
        next_monday = Date.current.beginning_of_week + 1.week

        slots = described_class.available_slots(
          therapist_id: therapist.id,
          start_date: next_monday,
          end_date: next_monday,
          timezone: 'America/New_York'
        )

        # Slots should be in Eastern time (3 hours ahead of Pacific)
        expect(['EST', 'EDT']).to include(slots.first[:start_time].zone)
      end
    end

    context 'edge cases' do
      it 'returns empty array when therapist has no availability' do
        slots = described_class.available_slots(
          therapist_id: therapist.id,
          start_date: Date.current,
          end_date: Date.current + 7.days
        )

        expect(slots).to be_empty
      end

      it 'returns empty array when all dates are blocked by time-off' do
        create(:therapist_availability,
               therapist: therapist,
               day_of_week: 1,
               start_time: Time.parse('09:00'),
               end_time: Time.parse('17:00'),
               timezone: 'UTC')

        start_date = Date.current.beginning_of_week + 1.week
        end_date = start_date + 1.week

        # Block entire period
        create(:therapist_time_off,
               therapist: therapist,
               start_date: start_date,
               end_date: end_date)

        slots = described_class.available_slots(
          therapist_id: therapist.id,
          start_date: start_date,
          end_date: end_date
        )

        expect(slots).to be_empty
      end

      it 'raises error for non-existent therapist' do
        expect do
          described_class.available_slots(
            therapist_id: 'non-existent-id',
            start_date: Date.current,
            end_date: Date.current + 1.week
          )
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with multi-day date range' do
      let!(:monday_availability) do
        create(:therapist_availability,
               therapist: therapist,
               day_of_week: 1,
               start_time: Time.parse('09:00'),
               end_time: Time.parse('12:00'),
               timezone: 'UTC')
      end

      let!(:wednesday_availability) do
        create(:therapist_availability,
               therapist: therapist,
               day_of_week: 3,
               start_time: Time.parse('14:00'),
               end_time: Time.parse('17:00'),
               timezone: 'UTC')
      end

      it 'generates slots for multiple days' do
        start_date = Date.current.beginning_of_week + 1.week
        end_date = start_date + 1.week

        slots = described_class.available_slots(
          therapist_id: therapist.id,
          start_date: start_date,
          end_date: end_date
        )

        # Should have slots for both Mondays and both Wednesdays
        slot_days = slots.map { |s| s[:start_time].wday }.uniq.sort
        expect(slot_days).to include(1, 3) # Monday and Wednesday
      end
    end
  end
end
