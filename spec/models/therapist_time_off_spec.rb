# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TherapistTimeOff, type: :model do
  # AC 5.2.2: Test time-off model for date overrides
  describe 'associations' do
    it { should belong_to(:therapist) }
  end

  describe 'validations' do
    # AC 5.2.2: Required fields
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }

    # AC 5.2.2: Start date before or equal to end date
    describe 'start_date_before_or_equal_to_end_date' do
      it 'rejects when start_date is after end_date' do
        time_off = build(:therapist_time_off,
                         start_date: 2.weeks.from_now.to_date,
                         end_date: 1.week.from_now.to_date)
        expect(time_off).not_to be_valid
        expect(time_off.errors[:end_date]).to include('must be on or after start date')
      end

      it 'accepts when start_date equals end_date' do
        date = 1.week.from_now.to_date
        time_off = build(:therapist_time_off,
                         start_date: date,
                         end_date: date)
        expect(time_off).to be_valid
      end

      it 'accepts when start_date is before end_date' do
        time_off = build(:therapist_time_off,
                         start_date: 1.week.from_now.to_date,
                         end_date: 2.weeks.from_now.to_date)
        expect(time_off).to be_valid
      end
    end

    # AC 5.2.2: Dates cannot be in past
    describe 'dates_not_in_past' do
      it 'rejects past start_date' do
        time_off = build(:therapist_time_off,
                         start_date: 1.week.ago.to_date,
                         end_date: 1.day.from_now.to_date)
        expect(time_off).not_to be_valid
        expect(time_off.errors[:start_date]).to include('cannot be in the past')
      end

      it 'rejects past end_date' do
        time_off = build(:therapist_time_off,
                         start_date: Date.current,
                         end_date: 1.day.ago.to_date)
        expect(time_off).not_to be_valid
        expect(time_off.errors[:end_date]).to include('cannot be in the past')
      end

      it 'accepts today as start_date' do
        time_off = build(:therapist_time_off,
                         start_date: Date.current,
                         end_date: 1.week.from_now.to_date)
        expect(time_off).to be_valid
      end

      it 'accepts future dates' do
        time_off = build(:therapist_time_off,
                         start_date: 1.week.from_now.to_date,
                         end_date: 2.weeks.from_now.to_date)
        expect(time_off).to be_valid
      end
    end

    # AC 5.2.2: Reason is optional
    it 'allows reason to be nil' do
      time_off = build(:therapist_time_off, reason: nil)
      expect(time_off).to be_valid
    end
  end

  describe 'scopes' do
    let(:therapist) { create(:therapist) }

    describe '.active' do
      it 'returns time-offs that have not ended yet' do
        active = create(:therapist_time_off,
                        therapist: therapist,
                        start_date: 1.week.from_now.to_date,
                        end_date: 2.weeks.from_now.to_date)

        result = TherapistTimeOff.active
        expect(result).to include(active)
      end
    end

    describe '.for_date_range' do
      it 'returns time-offs that overlap with given date range' do
        time_off = create(:therapist_time_off,
                          therapist: therapist,
                          start_date: 1.week.from_now.to_date,
                          end_date: 2.weeks.from_now.to_date)

        result = TherapistTimeOff.for_date_range(
          5.days.from_now.to_date,
          10.days.from_now.to_date
        )

        expect(result).to include(time_off)
      end

      it 'excludes time-offs outside date range' do
        time_off = create(:therapist_time_off,
                          therapist: therapist,
                          start_date: 1.week.from_now.to_date,
                          end_date: 2.weeks.from_now.to_date)

        result = TherapistTimeOff.for_date_range(
          3.weeks.from_now.to_date,
          4.weeks.from_now.to_date
        )

        expect(result).not_to include(time_off)
      end
    end
  end

  describe '#covers_date?' do
    let(:time_off) do
      create(:therapist_time_off,
             start_date: 1.week.from_now.to_date,
             end_date: 2.weeks.from_now.to_date)
    end

    it 'returns true for dates within the time-off period' do
      date = 10.days.from_now.to_date
      expect(time_off.covers_date?(date)).to be true
    end

    it 'returns true for start_date' do
      expect(time_off.covers_date?(time_off.start_date)).to be true
    end

    it 'returns true for end_date' do
      expect(time_off.covers_date?(time_off.end_date)).to be true
    end

    it 'returns false for dates before the period' do
      date = 3.days.from_now.to_date
      expect(time_off.covers_date?(date)).to be false
    end

    it 'returns false for dates after the period' do
      date = 3.weeks.from_now.to_date
      expect(time_off.covers_date?(date)).to be false
    end
  end
end
