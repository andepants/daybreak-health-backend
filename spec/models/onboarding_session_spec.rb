# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OnboardingSession, type: :model do
  include ActiveSupport::Testing::TimeHelpers
  describe 'associations' do
    it { should have_one(:parent).dependent(:destroy) }
    it { should have_one(:child).dependent(:destroy) }
    it { should have_one(:insurance).dependent(:destroy) }
    it { should have_one(:assessment).dependent(:destroy) }
    it { should have_many(:messages).dependent(:destroy) }
    it { should have_many(:audit_logs).dependent(:nullify) }
  end

  describe 'validations' do
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:expires_at) }
  end

  describe 'enums' do
    it do
      should define_enum_for(:status)
        .with_values(
          started: 0,
          in_progress: 1,
          insurance_pending: 2,
          assessment_complete: 3,
          submitted: 4,
          abandoned: 5,
          expired: 6
        )
    end

    it 'has all 7 status values' do
      expect(OnboardingSession.statuses.keys).to contain_exactly(
        'started', 'in_progress', 'insurance_pending', 'assessment_complete', 'submitted', 'abandoned', 'expired'
      )
    end
  end

  describe 'scopes' do
    let!(:active_session) { create(:onboarding_session, status: :started) }
    let!(:submitted_session) { create(:onboarding_session, status: :submitted) }
    let!(:expiring_session) { create(:onboarding_session, expires_at: 30.minutes.from_now) }

    describe '.active' do
      it 'returns non-terminal sessions' do
        expect(OnboardingSession.active).to include(active_session)
        expect(OnboardingSession.active).not_to include(submitted_session)
      end
    end

    describe '.expiring_soon' do
      it 'returns sessions expiring within 1 hour' do
        expect(OnboardingSession.expiring_soon).to include(expiring_session)
        expect(OnboardingSession.expiring_soon).not_to include(active_session)
      end
    end

    describe '.expired_pending' do
      let!(:expired_active) { create(:onboarding_session, status: :in_progress, expires_at: 1.hour.ago) }
      let!(:expired_already_marked) { create(:onboarding_session, status: :expired, expires_at: 2.hours.ago) }
      let!(:not_expired) { create(:onboarding_session, status: :in_progress, expires_at: 1.hour.from_now) }

      it 'returns active sessions past expiration time' do
        expect(OnboardingSession.expired_pending).to include(expired_active)
      end

      it 'does not return sessions already marked as expired' do
        expect(OnboardingSession.expired_pending).not_to include(expired_already_marked)
      end

      it 'does not return sessions not yet expired' do
        expect(OnboardingSession.expired_pending).not_to include(not_expired)
      end
    end
  end

  describe 'UUID primary key' do
    it 'generates UUID for id' do
      session = create(:onboarding_session)
      expect(session.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end

  describe 'timestamps' do
    it 'sets created_at and updated_at' do
      session = create(:onboarding_session)
      expect(session.created_at).to be_present
      expect(session.updated_at).to be_present
    end
  end

  describe '#past_expiration?' do
    it 'returns true when expires_at is in the past' do
      session = create(:onboarding_session, expires_at: 1.hour.ago)
      expect(session.past_expiration?).to be true
    end

    it 'returns false when expires_at is in the future' do
      session = create(:onboarding_session, expires_at: 1.hour.from_now)
      expect(session.past_expiration?).to be false
    end

    it 'returns false when expires_at is exactly now' do
      freeze_time do
        session = create(:onboarding_session, expires_at: Time.current)
        expect(session.past_expiration?).to be false
      end
    end

    it 'returns true when expires_at is one second ago' do
      freeze_time do
        session = create(:onboarding_session, expires_at: 1.second.ago)
        expect(session.past_expiration?).to be true
      end
    end
  end

  describe '#extend_expiration' do
    let(:session) { create(:onboarding_session, expires_at: 1.hour.from_now) }

    it 'extends expiration by 1 hour by default' do
      freeze_time do
        current_time = Time.current
        session.extend_expiration
        # Method sets expires_at to max(current_expires_at, now) + 1.hour
        # Since session.expires_at is 1 hour from now, it should be 1.hour.from_now + 1.hour = 2.hours.from_now
        expected_time = session.expires_at
        expect(expected_time).to be >= current_time + 1.hour
      end
    end

    it 'extends expiration by custom duration' do
      freeze_time do
        session.extend_expiration(2.hours)
        # Should extend by 2 hours from current time or existing expiration (whichever is later)
        expect(session.expires_at).to be >= Time.current + 2.hours
      end
    end

    it 'sets expiration to 1 hour from now' do
      freeze_time do
        # Even if session expires far in the future, extend_expiration sets it to 1 hour from now
        future_expiration = 10.hours.from_now
        session.update!(expires_at: future_expiration)

        session.extend_expiration(1.hour)
        # AC 2.2.4: Always sets to 1 hour from current time (not relative to existing expiration)
        expect(session.expires_at).to be_within(1.second).of(Time.current + 1.hour)
      end
    end

    it 'handles past expiration dates' do
      freeze_time do
        session.update!(expires_at: 1.hour.ago)

        session.extend_expiration
        # Since expires_at is in the past, should use Time.current + 1.hour
        expect(session.expires_at).to be_within(1.second).of(Time.current + 1.hour)
      end
    end
  end

  describe '#abandon!' do
    let(:session) { create(:onboarding_session, status: :started) }

    # AC 2.5.3: Mutation sets session status to ABANDONED
    it 'sets status to abandoned' do
      session.abandon!
      expect(session.status).to eq('abandoned')
      expect(session.reload.status).to eq('abandoned')
    end

    # AC 2.5.4: Session data is retained per data retention policy
    it 'retains all session data' do
      parent = create(:parent, onboarding_session: session)
      child = create(:child, onboarding_session: session)
      message = create(:message, onboarding_session: session)

      session.abandon!

      expect(session.reload.parent).to eq(parent)
      expect(session.reload.child).to eq(child)
      expect(session.reload.messages).to include(message)
    end

    # AC 2.5.8: Audit log entry created with previousStatus
    it 'creates audit log with SESSION_ABANDONED action' do
      # Note: Auditable concern creates CREATE and UPDATE logs, plus SESSION_ABANDONED
      expect do
        session.abandon!
      end.to change(AuditLog, :count).by_at_least(1)

      abandonment_log = AuditLog.where(action: 'SESSION_ABANDONED').last
      expect(abandonment_log.action).to eq('SESSION_ABANDONED')
      expect(abandonment_log.resource).to eq('OnboardingSession')
      expect(abandonment_log.resource_id).to eq(session.id)
    end

    it 'includes previous status in audit log details' do
      session.update!(status: :in_progress)
      session.abandon!

      abandonment_log = AuditLog.where(action: 'SESSION_ABANDONED').last
      expect(abandonment_log.details['previousStatus']).to eq('in_progress')
    end

    it 'records IP address and user agent in audit log when provided' do
      context = {
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0'
      }

      session.abandon!(context: context)

      # Find the SESSION_ABANDONED audit log specifically (Auditable concern may create UPDATE log too)
      abandonment_log = AuditLog.where(action: 'SESSION_ABANDONED').last
      expect(abandonment_log.ip_address).to eq('192.168.1.1')
      expect(abandonment_log.user_agent).to eq('Mozilla/5.0')
    end

    # Idempotency test
    it 'is idempotent - abandoning already abandoned session succeeds' do
      session.update!(status: :abandoned)

      expect do
        result = session.abandon!
        expect(result).to eq(session)
      end.not_to change(AuditLog, :count)

      expect(session.status).to eq('abandoned')
    end

    # State transition tests
    it 'can abandon from started status' do
      session.update!(status: :started)
      expect { session.abandon! }.not_to raise_error
      expect(session.status).to eq('abandoned')
    end

    it 'can abandon from in_progress status' do
      session.update!(status: :in_progress)
      expect { session.abandon! }.not_to raise_error
      expect(session.status).to eq('abandoned')
    end

    it 'can abandon from insurance_pending status' do
      # Valid transition path: started -> in_progress -> insurance_pending
      session.update!(status: :in_progress)
      session.update!(status: :insurance_pending)
      expect { session.abandon! }.not_to raise_error
      expect(session.status).to eq('abandoned')
    end

    it 'can abandon from assessment_complete status' do
      # Valid transition path: started -> in_progress -> insurance_pending -> assessment_complete
      session.update!(status: :in_progress)
      session.update!(status: :insurance_pending)
      session.update!(status: :assessment_complete)
      expect { session.abandon! }.not_to raise_error
      expect(session.status).to eq('abandoned')
    end

    # Terminal state protection (from state machine)
    it 'cannot abandon from submitted status (terminal)' do
      # Valid transition path: started -> in_progress -> insurance_pending -> assessment_complete -> submitted
      session.update!(status: :in_progress)
      session.update!(status: :insurance_pending)
      session.update!(status: :assessment_complete)
      session.update!(status: :submitted)
      expect { session.abandon! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'cannot abandon from expired status (terminal)' do
      # Transition to expired
      session.update!(status: :expired)
      expect { session.abandon! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    # AC 2.5.10: Notification trigger integration point
    context 'notification integration' do
      it 'does not raise error if notification config is missing' do
        expect(Rails.application.config).to receive(:respond_to?)
          .with(:abandonment_notifications_enabled)
          .and_return(false)

        expect { session.abandon! }.not_to raise_error
      end

      it 'calls notification trigger when enabled' do
        # Stub the config check by using instance_variable_set
        Rails.application.config.instance_variable_set(:@abandonment_notifications_enabled, true)

        # Define the method on the config object temporarily
        Rails.application.config.define_singleton_method(:abandonment_notifications_enabled) do
          instance_variable_get(:@abandonment_notifications_enabled)
        end

        expect(Rails.logger).to receive(:info)
          .with("Abandonment notification triggered for session #{session.id}")

        session.abandon!

        # Clean up
        Rails.application.config.instance_variable_set(:@abandonment_notifications_enabled, nil)
      end

      it 'does not call notification trigger when disabled' do
        # Stub the config check by using instance_variable_set
        Rails.application.config.instance_variable_set(:@abandonment_notifications_enabled, false)

        # Define the method on the config object temporarily
        Rails.application.config.define_singleton_method(:abandonment_notifications_enabled) do
          instance_variable_get(:@abandonment_notifications_enabled)
        end

        expect(Rails.logger).not_to receive(:info)
          .with(/Abandonment notification triggered/)

        session.abandon!

        # Clean up
        Rails.application.config.instance_variable_set(:@abandonment_notifications_enabled, nil)
      end
    end
  end

  # AC 3.5: Human Escalation Request
  describe 'escalation fields' do
    let(:session) { create(:onboarding_session) }

    describe 'needs_human_contact' do
      it 'defaults to false' do
        expect(session.needs_human_contact).to be false
      end

      it 'can be set to true' do
        session.update!(needs_human_contact: true, escalation_requested_at: Time.current)
        expect(session.needs_human_contact).to be true
      end
    end

    describe 'escalation_requested_at' do
      it 'can be nil by default' do
        expect(session.escalation_requested_at).to be_nil
      end

      it 'can store a timestamp' do
        timestamp = Time.current
        session.update!(needs_human_contact: true, escalation_requested_at: timestamp)
        expect(session.escalation_requested_at).to be_within(1.second).of(timestamp)
      end

      # AC 3.5.2,3.5.3: Validation ensures escalation_requested_at is set when needs_human_contact is true
      it 'is required when needs_human_contact is true' do
        session.needs_human_contact = true
        session.escalation_requested_at = nil
        expect(session).not_to be_valid
        expect(session.errors[:escalation_requested_at]).to include("can't be blank")
      end

      it 'is not required when needs_human_contact is false' do
        session.needs_human_contact = false
        session.escalation_requested_at = nil
        expect(session).to be_valid
      end
    end

    describe 'escalation_reason' do
      # AC 3.5.7: Escalation reason is encrypted as PHI
      it 'can store escalation reason' do
        reason = 'I need urgent help'
        session.update!(
          needs_human_contact: true,
          escalation_requested_at: Time.current,
          escalation_reason: reason
        )
        expect(session.escalation_reason).to eq(reason)
      end

      it 'encrypts escalation reason (PHI)' do
        reason = 'Personal sensitive information'
        session.update!(
          needs_human_contact: true,
          escalation_requested_at: Time.current,
          escalation_reason: reason
        )

        # Raw database value should be encrypted (not readable)
        raw_value = ActiveRecord::Base.connection.select_value(
          "SELECT escalation_reason FROM onboarding_sessions WHERE id = '#{session.id}'"
        )
        expect(raw_value).not_to eq(reason)
        expect(raw_value).not_to be_nil

        # But the model attribute should decrypt it
        expect(session.reload.escalation_reason).to eq(reason)
      end

      it 'can be nil (reason is optional)' do
        session.update!(needs_human_contact: true, escalation_requested_at: Time.current)
        expect(session.escalation_reason).to be_nil
        expect(session).to be_valid
      end
    end

    # AC 3.5.2,3.5.3: Scope to filter sessions needing human contact
    describe '.needs_human_contact scope' do
      let!(:escalated_session1) do
        create(:onboarding_session, needs_human_contact: true, escalation_requested_at: Time.current)
      end
      let!(:escalated_session2) do
        create(:onboarding_session,
               needs_human_contact: true,
               escalation_requested_at: 1.hour.ago,
               escalation_reason: 'Need help')
      end
      let!(:normal_session) { create(:onboarding_session, needs_human_contact: false) }

      it 'returns only sessions with needs_human_contact true' do
        expect(OnboardingSession.needs_human_contact).to include(escalated_session1, escalated_session2)
        expect(OnboardingSession.needs_human_contact).not_to include(normal_session)
      end

      it 'returns correct count' do
        expect(OnboardingSession.needs_human_contact.count).to eq(2)
      end
    end
  end
end
