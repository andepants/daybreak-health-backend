# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Scheduling::BookingService, type: :service do
  let(:therapist) { create(:therapist, active: true, appointment_duration_minutes: 50) }
  let(:session) { create(:onboarding_session, status: :assessment_complete) }
  let(:scheduled_at) { 2.days.from_now.change(hour: 10, min: 0) }

  describe '.book_appointment' do
    context 'with valid parameters' do
      it 'creates appointment successfully' do
        result = described_class.book_appointment(
          session_id: session.id,
          therapist_id: therapist.id,
          scheduled_at: scheduled_at,
          duration_minutes: 50
        )

        expect(result.success?).to be true
        expect(result.appointment).to be_persisted
        expect(result.appointment.therapist).to eq(therapist)
        expect(result.appointment.onboarding_session).to eq(session)
        expect(result.appointment.scheduled_at).to eq(scheduled_at)
        expect(result.appointment.duration_minutes).to eq(50)
        expect(result.appointment).to be_scheduled
      end

      it 'uses therapist default duration if not provided' do
        result = described_class.book_appointment(
          session_id: session.id,
          therapist_id: therapist.id,
          scheduled_at: scheduled_at
        )

        expect(result.success?).to be true
        expect(result.appointment.duration_minutes).to eq(therapist.appointment_duration_minutes)
      end

      it 'sets location_type to virtual' do
        result = described_class.book_appointment(
          session_id: session.id,
          therapist_id: therapist.id,
          scheduled_at: scheduled_at
        )

        expect(result.success?).to be true
        expect(result.appointment.location_type).to eq('virtual')
      end

      it 'generates virtual link' do
        result = described_class.book_appointment(
          session_id: session.id,
          therapist_id: therapist.id,
          scheduled_at: scheduled_at
        )

        expect(result.success?).to be true
        expect(result.appointment.virtual_link).to include('meet.daybreakhealth.com')
        expect(result.appointment.virtual_link).to include(session.id)
      end

      it 'updates session status to appointment_booked' do
        expect do
          described_class.book_appointment(
            session_id: session.id,
            therapist_id: therapist.id,
            scheduled_at: scheduled_at
          )
        end.to change { session.reload.status }.from('assessment_complete').to('appointment_booked')
      end
    end

    context 'with invalid parameters' do
      it 'fails when therapist not found' do
        result = described_class.book_appointment(
          session_id: session.id,
          therapist_id: 'invalid-id',
          scheduled_at: scheduled_at
        )

        expect(result.failure?).to be true
        expect(result.errors).to include('Therapist not found')
      end

      it 'fails when therapist is inactive' do
        inactive_therapist = create(:therapist, active: false)
        result = described_class.book_appointment(
          session_id: session.id,
          therapist_id: inactive_therapist.id,
          scheduled_at: scheduled_at
        )

        expect(result.failure?).to be true
        expect(result.errors).to include('Therapist is not active')
      end

      it 'fails when session not found' do
        result = described_class.book_appointment(
          session_id: 'invalid-id',
          therapist_id: therapist.id,
          scheduled_at: scheduled_at
        )

        expect(result.failure?).to be true
        expect(result.errors).to include('Session not found')
      end

      it 'fails when session not in assessment_complete status' do
        in_progress_session = create(:onboarding_session, status: :in_progress)
        result = described_class.book_appointment(
          session_id: in_progress_session.id,
          therapist_id: therapist.id,
          scheduled_at: scheduled_at
        )

        expect(result.failure?).to be true
        expect(result.errors).to include('Session must be in assessment_complete status before booking')
      end

      it 'fails when scheduled_at is in the past' do
        result = described_class.book_appointment(
          session_id: session.id,
          therapist_id: therapist.id,
          scheduled_at: 1.day.ago
        )

        expect(result.failure?).to be true
        expect(result.errors).to include('Appointment must be scheduled in the future')
      end

      it 'fails when slot is already booked' do
        create(:appointment,
               therapist: therapist,
               scheduled_at: scheduled_at,
               duration_minutes: 50)

        result = described_class.book_appointment(
          session_id: session.id,
          therapist_id: therapist.id,
          scheduled_at: scheduled_at
        )

        expect(result.failure?).to be true
        expect(result.errors).to include('This time slot is no longer available')
      end
    end

    context 'race condition handling' do
      it 'prevents double-booking with concurrent requests' do
        session2 = create(:onboarding_session, status: :assessment_complete)

        results = []
        threads = []

        # Simulate 2 concurrent booking attempts for the same slot
        2.times do |i|
          threads << Thread.new do
            result = described_class.book_appointment(
              session_id: i.zero? ? session.id : session2.id,
              therapist_id: therapist.id,
              scheduled_at: scheduled_at,
              duration_minutes: 50
            )
            results << result
          end
        end

        threads.each(&:join)

        # Exactly one should succeed
        successful = results.count(&:success?)
        failed = results.count(&:failure?)

        expect(successful).to eq(1)
        expect(failed).to eq(1)

        # Verify only one appointment created
        appointments = Appointment.where(
          therapist: therapist,
          scheduled_at: scheduled_at
        )
        expect(appointments.count).to eq(1)
      end

      it 'prevents double-booking with multiple concurrent attempts' do
        sessions = 5.times.map { create(:onboarding_session, status: :assessment_complete) }

        results = []
        threads = []

        # Simulate 5 concurrent booking attempts
        sessions.each do |sess|
          threads << Thread.new do
            result = described_class.book_appointment(
              session_id: sess.id,
              therapist_id: therapist.id,
              scheduled_at: scheduled_at,
              duration_minutes: 50
            )
            results << result
          end
        end

        threads.each(&:join)

        # Exactly one should succeed
        successful = results.count(&:success?)
        expect(successful).to eq(1)

        # Verify only one appointment created
        appointments = Appointment.where(
          therapist: therapist,
          scheduled_at: scheduled_at
        )
        expect(appointments.count).to eq(1)
      end
    end

    context 'transaction rollback' do
      it 'does not create appointment if session update fails' do
        allow_any_instance_of(Appointment).to receive(:save).and_return(false)

        expect do
          described_class.book_appointment(
            session_id: session.id,
            therapist_id: therapist.id,
            scheduled_at: scheduled_at
          )
        end.not_to change(Appointment, :count)
      end

      it 'does not update session if appointment creation fails' do
        allow_any_instance_of(Appointment).to receive(:save).and_return(false)

        expect do
          described_class.book_appointment(
            session_id: session.id,
            therapist_id: therapist.id,
            scheduled_at: scheduled_at
          )
        end.not_to change { session.reload.status }
      end
    end
  end

  describe '.cancel_appointment' do
    let!(:appointment) { create(:appointment, scheduled_at: 48.hours.from_now) }

    context 'with valid parameters' do
      it 'cancels appointment successfully' do
        result = described_class.cancel_appointment(
          appointment_id: appointment.id,
          reason: 'Parent requested'
        )

        expect(result.success?).to be true
        expect(result.appointment.reload).to be_cancelled
        expect(result.appointment.cancellation_reason).to eq('Parent requested')
        expect(result.appointment.cancelled_at).to be_present
      end

      it 'works without reason' do
        result = described_class.cancel_appointment(
          appointment_id: appointment.id
        )

        expect(result.success?).to be true
        expect(result.appointment.reload).to be_cancelled
      end
    end

    context 'with invalid parameters' do
      it 'fails when appointment not found' do
        result = described_class.cancel_appointment(
          appointment_id: 'invalid-id'
        )

        expect(result.failure?).to be true
        expect(result.errors).to include('Appointment not found')
      end

      it 'fails when appointment is within 24 hours' do
        near_appointment = create(:appointment, scheduled_at: 12.hours.from_now)
        result = described_class.cancel_appointment(
          appointment_id: near_appointment.id
        )

        expect(result.failure?).to be true
        expect(result.errors).to include('Appointment cannot be cancelled (must be at least 24 hours in advance)')
      end

      it 'fails when appointment already cancelled' do
        appointment.update(status: :cancelled, cancelled_at: Time.current)
        result = described_class.cancel_appointment(
          appointment_id: appointment.id
        )

        expect(result.failure?).to be true
      end
    end
  end

  describe '.reschedule_appointment' do
    let!(:appointment) { create(:appointment, therapist: therapist, scheduled_at: 48.hours.from_now) }
    let(:new_scheduled_at) { 3.days.from_now.change(hour: 14, min: 0) }

    context 'with valid parameters' do
      it 'reschedules appointment successfully' do
        result = described_class.reschedule_appointment(
          appointment_id: appointment.id,
          new_scheduled_at: new_scheduled_at
        )

        expect(result.success?).to be true
        expect(result.appointment).to be_persisted
        expect(result.appointment.id).not_to eq(appointment.id)
        expect(result.appointment.scheduled_at).to eq(new_scheduled_at)
        expect(result.appointment.therapist).to eq(therapist)

        # Old appointment should be cancelled
        expect(appointment.reload).to be_cancelled
        expect(appointment.cancellation_reason).to eq('Rescheduled to new time')
      end

      it 'preserves appointment details' do
        result = described_class.reschedule_appointment(
          appointment_id: appointment.id,
          new_scheduled_at: new_scheduled_at
        )

        expect(result.success?).to be true
        expect(result.appointment.duration_minutes).to eq(appointment.duration_minutes)
        expect(result.appointment.location_type).to eq(appointment.location_type)
        expect(result.appointment.virtual_link).to eq(appointment.virtual_link)
      end
    end

    context 'with invalid parameters' do
      it 'fails when appointment not found' do
        result = described_class.reschedule_appointment(
          appointment_id: 'invalid-id',
          new_scheduled_at: new_scheduled_at
        )

        expect(result.failure?).to be true
        expect(result.errors).to include('Appointment not found')
      end

      it 'fails when appointment within 24 hours' do
        near_appointment = create(:appointment, scheduled_at: 12.hours.from_now)
        result = described_class.reschedule_appointment(
          appointment_id: near_appointment.id,
          new_scheduled_at: new_scheduled_at
        )

        expect(result.failure?).to be true
        expect(result.errors).to include('Appointment cannot be rescheduled (must be at least 24 hours in advance)')
      end

      it 'fails when new slot is unavailable' do
        create(:appointment, therapist: therapist, scheduled_at: new_scheduled_at)

        result = described_class.reschedule_appointment(
          appointment_id: appointment.id,
          new_scheduled_at: new_scheduled_at
        )

        expect(result.failure?).to be true
        expect(result.errors).to include('New time slot is not available')
      end
    end

    context 'transaction rollback' do
      it 'does not cancel old appointment if new appointment fails' do
        allow_any_instance_of(Appointment).to receive(:save).and_return(false)

        expect do
          described_class.reschedule_appointment(
            appointment_id: appointment.id,
            new_scheduled_at: new_scheduled_at
          )
        end.not_to change { appointment.reload.status }
      end
    end
  end

  describe 'performance' do
    it 'completes booking within acceptable time' do
      start_time = Time.current

      described_class.book_appointment(
        session_id: session.id,
        therapist_id: therapist.id,
        scheduled_at: scheduled_at
      )

      duration = Time.current - start_time

      # Should complete well within 500ms (p95 requirement)
      expect(duration).to be < 0.5
    end
  end
end
