# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TherapistAvailability, type: :model do
  # AC 5.2.1: Test recurring availability slots model
  describe 'associations' do
    it { should belong_to(:therapist) }
  end

  describe 'validations' do
    # AC 5.2.1: Required fields
    it { should validate_presence_of(:day_of_week) }
    it { should validate_presence_of(:start_time) }
    it { should validate_presence_of(:end_time) }
    it { should validate_presence_of(:timezone) }

    # AC 5.2.1: Day of week must be 0-6
    it { should validate_inclusion_of(:day_of_week).in_range(0..6) }

    # AC 5.2.5: Timezone validation
    it 'validates timezone is a valid IANA timezone' do
      availability = build(:therapist_availability, timezone: 'America/Los_Angeles')
      expect(availability).to be_valid
    end

    it 'rejects invalid timezones' do
      availability = build(:therapist_availability, timezone: 'Invalid/Timezone')
      expect(availability).not_to be_valid
      expect(availability.errors[:timezone]).to be_present
    end

    # AC 5.2.1: Start time before end time
    describe 'start_time_before_end_time' do
      it 'rejects when start_time is after end_time' do
        availability = build(:therapist_availability,
                             start_time: Time.parse('17:00'),
                             end_time: Time.parse('09:00'))
        expect(availability).not_to be_valid
        expect(availability.errors[:end_time]).to include('must be after start time')
      end

      it 'rejects when start_time equals end_time' do
        availability = build(:therapist_availability,
                             start_time: Time.parse('09:00'),
                             end_time: Time.parse('09:00'))
        expect(availability).not_to be_valid
        expect(availability.errors[:end_time]).to include('must be after start time')
      end

      it 'accepts when start_time is before end_time' do
        availability = build(:therapist_availability,
                             start_time: Time.parse('09:00'),
                             end_time: Time.parse('17:00'))
        expect(availability).to be_valid
      end
    end

    # AC 5.2.7: No overlapping slots for same therapist on same day
    describe 'no_overlapping_slots' do
      let(:therapist) { create(:therapist) }

      it 'rejects overlapping availability slots' do
        create(:therapist_availability,
               therapist: therapist,
               day_of_week: 1,
               start_time: Time.parse('09:00'),
               end_time: Time.parse('12:00'))

        overlapping = build(:therapist_availability,
                            therapist: therapist,
                            day_of_week: 1,
                            start_time: Time.parse('10:00'),
                            end_time: Time.parse('14:00'))

        expect(overlapping).not_to be_valid
        expect(overlapping.errors[:base]).to include('This availability slot overlaps with an existing slot for this therapist')
      end

      it 'allows non-overlapping slots on same day' do
        create(:therapist_availability,
               therapist: therapist,
               day_of_week: 1,
               start_time: Time.parse('09:00'),
               end_time: Time.parse('12:00'))

        non_overlapping = build(:therapist_availability,
                                therapist: therapist,
                                day_of_week: 1,
                                start_time: Time.parse('13:00'),
                                end_time: Time.parse('17:00'))

        expect(non_overlapping).to be_valid
      end

      it 'allows overlapping times on different days' do
        create(:therapist_availability,
               therapist: therapist,
               day_of_week: 1,
               start_time: Time.parse('09:00'),
               end_time: Time.parse('12:00'))

        different_day = build(:therapist_availability,
                              therapist: therapist,
                              day_of_week: 2,
                              start_time: Time.parse('09:00'),
                              end_time: Time.parse('12:00'))

        expect(different_day).to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:therapist) { create(:therapist) }

    describe '.for_day_of_week' do
      it 'returns availabilities for specific day of week' do
        monday = create(:therapist_availability, therapist: therapist, day_of_week: 1)
        tuesday = create(:therapist_availability, therapist: therapist, day_of_week: 2)

        result = TherapistAvailability.for_day_of_week(1)
        expect(result).to include(monday)
        expect(result).not_to include(tuesday)
      end
    end

    describe '.repeating' do
      it 'returns only repeating availabilities' do
        repeating = create(:therapist_availability, therapist: therapist, is_repeating: true)
        one_time = create(:therapist_availability, therapist: therapist, is_repeating: false)

        result = TherapistAvailability.repeating
        expect(result).to include(repeating)
        expect(result).not_to include(one_time)
      end
    end
  end

  describe '.overlapping' do
    let(:therapist) { create(:therapist) }

    it 'finds overlapping availability slots' do
      existing = create(:therapist_availability,
                        therapist: therapist,
                        day_of_week: 1,
                        start_time: Time.parse('09:00'),
                        end_time: Time.parse('12:00'))

      result = TherapistAvailability.overlapping(
        therapist.id,
        1,
        Time.parse('10:00'),
        Time.parse('14:00')
      )

      expect(result).to include(existing)
    end

    it 'excludes non-overlapping slots' do
      non_overlapping = create(:therapist_availability,
                               therapist: therapist,
                               day_of_week: 1,
                               start_time: Time.parse('09:00'),
                               end_time: Time.parse('12:00'))

      result = TherapistAvailability.overlapping(
        therapist.id,
        1,
        Time.parse('13:00'),
        Time.parse('17:00')
      )

      expect(result).not_to include(non_overlapping)
    end
  end
end
