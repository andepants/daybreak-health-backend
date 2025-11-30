# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Appointment, type: :model do
  describe 'associations' do
    it { should belong_to(:therapist) }
    it { should belong_to(:onboarding_session) }
  end

  describe 'validations' do
    subject { build(:appointment) }

    it { should validate_presence_of(:scheduled_at) }
    it { should validate_presence_of(:duration_minutes) }
    it { should validate_numericality_of(:duration_minutes).is_greater_than(0) }
    it { should validate_presence_of(:status) }

    describe 'scheduled_at_in_future' do
      context 'when creating appointment' do
        it 'allows future dates' do
          appointment = build(:appointment, scheduled_at: 1.day.from_now)
          expect(appointment).to be_valid
        end

        it 'rejects past dates' do
          appointment = build(:appointment, scheduled_at: 1.day.ago)
          expect(appointment).not_to be_valid
          expect(appointment.errors[:scheduled_at]).to include('must be in the future')
        end

        it 'rejects current time' do
          appointment = build(:appointment, scheduled_at: Time.current)
          expect(appointment).not_to be_valid
        end
      end
    end

    describe 'therapist_must_be_active' do
      it 'allows active therapist' do
        therapist = create(:therapist, active: true)
        appointment = build(:appointment, therapist: therapist)
        expect(appointment).to be_valid
      end

      it 'rejects inactive therapist' do
        therapist = create(:therapist, active: false)
        appointment = build(:appointment, therapist: therapist)
        expect(appointment).not_to be_valid
        expect(appointment.errors[:therapist]).to include('must be active')
      end
    end

    describe 'session_must_be_assessment_complete' do
      it 'allows assessment_complete session' do
        session = create(:onboarding_session, status: :assessment_complete)
        appointment = build(:appointment, onboarding_session: session)
        expect(appointment).to be_valid
      end

      it 'rejects non-assessment_complete session' do
        session = create(:onboarding_session, status: :in_progress)
        appointment = build(:appointment, onboarding_session: session)
        expect(appointment).not_to be_valid
        expect(appointment.errors[:onboarding_session])
          .to include('must be in assessment_complete status before booking')
      end
    end

    describe 'no_double_booking' do
      let(:therapist) { create(:therapist) }
      let(:session) { create(:onboarding_session, status: :assessment_complete) }
      let!(:existing_appointment) do
        create(:appointment,
               therapist: therapist,
               scheduled_at: 2.days.from_now.change(hour: 10, min: 0),
               duration_minutes: 50)
      end

      it 'allows non-overlapping appointments' do
        # Schedule at 11:00 (existing is 10:00-10:50)
        appointment = build(:appointment,
                            therapist: therapist,
                            onboarding_session: session,
                            scheduled_at: 2.days.from_now.change(hour: 11, min: 0))
        expect(appointment).to be_valid
      end

      it 'rejects overlapping appointments - same start time' do
        appointment = build(:appointment,
                            therapist: therapist,
                            onboarding_session: session,
                            scheduled_at: existing_appointment.scheduled_at)
        expect(appointment).not_to be_valid
        expect(appointment.errors[:base]).to include('This time slot conflicts with an existing appointment')
      end

      it 'rejects overlapping appointments - starts during existing' do
        # Start at 10:30 (overlaps with 10:00-10:50)
        appointment = build(:appointment,
                            therapist: therapist,
                            onboarding_session: session,
                            scheduled_at: 2.days.from_now.change(hour: 10, min: 30))
        expect(appointment).not_to be_valid
      end

      it 'rejects overlapping appointments - ends during existing' do
        # Start at 9:30, ends at 10:20 (overlaps with 10:00-10:50)
        appointment = build(:appointment,
                            therapist: therapist,
                            onboarding_session: session,
                            scheduled_at: 2.days.from_now.change(hour: 9, min: 30),
                            duration_minutes: 50)
        expect(appointment).not_to be_valid
      end

      it 'allows booking for different therapist at same time' do
        other_therapist = create(:therapist)
        appointment = build(:appointment,
                            therapist: other_therapist,
                            onboarding_session: session,
                            scheduled_at: existing_appointment.scheduled_at)
        expect(appointment).to be_valid
      end

      it 'ignores cancelled appointments for overlap check' do
        existing_appointment.update(status: :cancelled, cancelled_at: Time.current)
        appointment = build(:appointment,
                            therapist: therapist,
                            onboarding_session: session,
                            scheduled_at: existing_appointment.scheduled_at)
        expect(appointment).to be_valid
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(scheduled: 0, confirmed: 1, cancelled: 2, completed: 3, no_show: 4) }
  end

  describe 'scopes' do
    let!(:upcoming_appt) { create(:appointment, :upcoming) }
    let!(:past_appt) { create(:appointment, :past) }
    let!(:cancelled_appt) { create(:appointment, :cancelled) }
    let!(:completed_appt) { create(:appointment, :completed) }

    describe '.upcoming' do
      it 'returns only future non-cancelled/completed appointments' do
        expect(Appointment.upcoming).to include(upcoming_appt)
        expect(Appointment.upcoming).not_to include(past_appt, cancelled_appt, completed_appt)
      end
    end

    describe '.past' do
      it 'returns only past appointments' do
        expect(Appointment.past).to include(past_appt, completed_appt)
        expect(Appointment.past).not_to include(upcoming_appt)
      end
    end

    describe '.active' do
      it 'returns non-cancelled appointments' do
        expect(Appointment.active).to include(upcoming_appt, past_appt, completed_appt)
        expect(Appointment.active).not_to include(cancelled_appt)
      end
    end

    describe '.for_therapist' do
      let(:therapist) { upcoming_appt.therapist }

      it 'returns appointments for specific therapist' do
        expect(Appointment.for_therapist(therapist.id)).to include(upcoming_appt)
      end
    end

    describe '.for_session' do
      let(:session) { upcoming_appt.onboarding_session }

      it 'returns appointments for specific session' do
        expect(Appointment.for_session(session.id)).to include(upcoming_appt)
      end
    end

    describe '.on_date' do
      let(:target_date) { 1.week.from_now.to_date }
      let!(:appointment_on_date) do
        create(:appointment, scheduled_at: target_date.to_time.change(hour: 10))
      end

      it 'returns appointments on specific date' do
        expect(Appointment.on_date(target_date)).to include(appointment_on_date)
        expect(Appointment.on_date(target_date)).not_to include(upcoming_appt)
      end
    end
  end

  describe 'callbacks' do
    describe 'after_create' do
      it 'updates session status to appointment_booked' do
        session = create(:onboarding_session, status: :assessment_complete)
        expect do
          create(:appointment, onboarding_session: session)
        end.to change { session.reload.status }.from('assessment_complete').to('appointment_booked')
      end
    end
  end

  describe '#confirmation_number' do
    it 'generates confirmation number from ID' do
      appointment = create(:appointment)
      expect(appointment.confirmation_number).to match(/^APT-[A-Z0-9]{8}$/)
    end
  end

  describe '#cancellable?' do
    it 'returns true for scheduled appointment more than 24 hours away' do
      appointment = create(:appointment, scheduled_at: 48.hours.from_now)
      expect(appointment.cancellable?).to be true
    end

    it 'returns false for appointment less than 24 hours away' do
      appointment = create(:appointment, scheduled_at: 12.hours.from_now)
      expect(appointment.cancellable?).to be false
    end

    it 'returns false for cancelled appointment' do
      appointment = create(:appointment, :cancelled, scheduled_at: 48.hours.from_now)
      expect(appointment.cancellable?).to be false
    end

    it 'returns false for completed appointment' do
      appointment = create(:appointment, :completed)
      expect(appointment.cancellable?).to be false
    end

    it 'returns false for past appointment' do
      appointment = create(:appointment, :past)
      expect(appointment.cancellable?).to be false
    end
  end

  describe '#cancel!' do
    it 'cancels appointment with reason' do
      appointment = create(:appointment, scheduled_at: 48.hours.from_now)
      result = appointment.cancel!(reason: 'Parent requested')

      expect(result).to be true
      expect(appointment.reload).to be_cancelled
      expect(appointment.cancellation_reason).to eq('Parent requested')
      expect(appointment.cancelled_at).to be_present
    end

    it 'returns false if not cancellable' do
      appointment = create(:appointment, scheduled_at: 12.hours.from_now)
      result = appointment.cancel!(reason: 'Test')

      expect(result).to be false
      expect(appointment.reload).to be_scheduled
    end
  end

  describe '#confirm!' do
    it 'confirms scheduled appointment' do
      appointment = create(:appointment, status: :scheduled)
      result = appointment.confirm!

      expect(result).to be true
      expect(appointment.reload).to be_confirmed
      expect(appointment.confirmed_at).to be_present
    end

    it 'returns false if not scheduled' do
      appointment = create(:appointment, :cancelled)
      result = appointment.confirm!

      expect(result).to be false
    end
  end

  describe '#complete!' do
    it 'marks past appointment as completed' do
      appointment = create(:appointment, :past, status: :scheduled)
      result = appointment.complete!

      expect(result).to be true
      expect(appointment.reload).to be_completed
    end

    it 'returns false for future appointment' do
      appointment = create(:appointment, :upcoming)
      result = appointment.complete!

      expect(result).to be false
    end
  end

  describe '#mark_no_show!' do
    it 'marks past appointment as no-show' do
      appointment = create(:appointment, :past, status: :scheduled)
      result = appointment.mark_no_show!

      expect(result).to be true
      expect(appointment.reload).to be_no_show
    end

    it 'returns false for future appointment' do
      appointment = create(:appointment, :upcoming)
      result = appointment.mark_no_show!

      expect(result).to be false
    end
  end

  describe '#past?' do
    it 'returns true for past appointments' do
      appointment = create(:appointment, :past)
      expect(appointment.past?).to be true
    end

    it 'returns false for future appointments' do
      appointment = create(:appointment, :upcoming)
      expect(appointment.past?).to be false
    end
  end

  describe '#future?' do
    it 'returns true for future appointments' do
      appointment = create(:appointment, :upcoming)
      expect(appointment.future?).to be true
    end

    it 'returns false for past appointments' do
      appointment = create(:appointment, :past)
      expect(appointment.future?).to be false
    end
  end

  describe 'database constraints' do
    it 'enforces unique index on therapist_id and scheduled_at' do
      therapist = create(:therapist)
      session1 = create(:onboarding_session, status: :assessment_complete)
      session2 = create(:onboarding_session, status: :assessment_complete)
      scheduled_time = 2.days.from_now.change(hour: 10, min: 0)

      create(:appointment, therapist: therapist, onboarding_session: session1, scheduled_at: scheduled_time)

      expect do
        create(:appointment, therapist: therapist, onboarding_session: session2, scheduled_at: scheduled_time)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
