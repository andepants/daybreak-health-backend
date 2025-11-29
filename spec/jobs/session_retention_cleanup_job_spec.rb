# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionRetentionCleanupJob, type: :job do
  describe '#perform' do
    let(:retention_days) { 90 }
    let(:retention_threshold) { retention_days.days.ago }

    before do
      # Ensure consistent retention period for tests
      allow(Rails.configuration).to receive(:data_retention_days).and_return(retention_days)
    end

    context 'with expired sessions past retention period' do
      let!(:old_expired_session) do
        create(:onboarding_session,
               status: :expired,
               updated_at: 91.days.ago,
               expires_at: 115.days.ago) # Expired 115 days ago
      end

      let!(:very_old_expired_session) do
        create(:onboarding_session,
               status: :expired,
               updated_at: 180.days.ago,
               expires_at: 200.days.ago)
      end

      it 'deletes expired sessions past retention period' do
        expect {
          described_class.perform_now
        }.to change { OnboardingSession.count }.by(-2)

        expect(OnboardingSession.exists?(old_expired_session.id)).to be false
        expect(OnboardingSession.exists?(very_old_expired_session.id)).to be false
      end

      it 'returns the count of deleted sessions' do
        result = described_class.perform_now
        expect(result).to eq(2)
      end

      it 'creates audit log entries before deletion' do
        # Capture audit logs before sessions are deleted
        session_ids = [old_expired_session.id, very_old_expired_session.id]

        described_class.perform_now

        # Check for SESSION_DELETED audit logs
        audit_logs = AuditLog.where(action: 'SESSION_DELETED', resource_id: session_ids)
        expect(audit_logs.count).to eq(2)
      end

      it 'includes required details in audit log' do
        old_session_id = old_expired_session.id
        old_session_created_at = old_expired_session.created_at
        old_session_updated_at = old_expired_session.updated_at

        described_class.perform_now

        audit_log = AuditLog.find_by(resource_id: old_session_id, action: 'SESSION_DELETED')
        expect(audit_log).to be_present
        expect(audit_log.onboarding_session_id).to be_nil # Session is deleted, don't link
        expect(audit_log.resource).to eq('OnboardingSession')
        expect(audit_log.details).to include('deleted_at', 'retention_period_days', 'expired_at', 'created_at')
        expect(audit_log.details['retention_period_days']).to eq(90)
        # Parse timestamps from JSON strings for comparison
        expect(Time.zone.parse(audit_log.details['created_at'])).to be_within(1.second).of(old_session_created_at)
        expect(Time.zone.parse(audit_log.details['expired_at'])).to be_within(1.second).of(old_session_updated_at)
      end

      it 'logs the count of deleted sessions' do
        allow(Rails.logger).to receive(:info)

        expect(Rails.logger).to receive(:info).with(include('Starting retention cleanup'))
        expect(Rails.logger).to receive(:info).with(include('Deleted 2 session(s)'))

        described_class.perform_now
      end
    end

    context 'with expired sessions within retention period' do
      let!(:recent_expired_session) do
        create(:onboarding_session,
               status: :expired,
               updated_at: 30.days.ago,
               expires_at: 54.days.ago)
      end

      let!(:borderline_expired_session) do
        create(:onboarding_session,
               status: :expired,
               updated_at: 89.days.ago,
               expires_at: 113.days.ago)
      end

      it 'does not delete sessions within retention period' do
        expect {
          described_class.perform_now
        }.not_to change { OnboardingSession.count }

        expect(OnboardingSession.exists?(recent_expired_session.id)).to be true
        expect(OnboardingSession.exists?(borderline_expired_session.id)).to be true
      end

      it 'returns zero when no sessions are deleted' do
        result = described_class.perform_now
        expect(result).to eq(0)
      end

      it 'does not create audit logs for non-deleted sessions' do
        expect {
          described_class.perform_now
        }.not_to change { AuditLog.where(action: 'SESSION_DELETED').count }
      end
    end

    context 'with mixed session statuses' do
      let!(:active_session) do
        create(:onboarding_session,
               status: :in_progress,
               updated_at: 100.days.ago)
      end

      let!(:abandoned_session) do
        create(:onboarding_session,
               status: :abandoned,
               updated_at: 100.days.ago)
      end

      let!(:submitted_session) do
        create(:onboarding_session,
               status: :submitted,
               updated_at: 100.days.ago)
      end

      let!(:old_expired_session) do
        create(:onboarding_session,
               status: :expired,
               updated_at: 100.days.ago)
      end

      it 'only deletes expired sessions' do
        expect {
          described_class.perform_now
        }.to change { OnboardingSession.count }.by(-1)

        expect(OnboardingSession.exists?(active_session.id)).to be true
        expect(OnboardingSession.exists?(abandoned_session.id)).to be true
        expect(OnboardingSession.exists?(submitted_session.id)).to be true
        expect(OnboardingSession.exists?(old_expired_session.id)).to be false
      end
    end

    context 'with associated data' do
      let!(:old_expired_session) do
        create(:onboarding_session,
               status: :expired,
               updated_at: 100.days.ago)
      end

      let!(:parent) { create(:parent, onboarding_session: old_expired_session) }
      let!(:child) { create(:child, onboarding_session: old_expired_session) }
      let!(:insurance) { create(:insurance, onboarding_session: old_expired_session) }
      let!(:message) { create(:message, onboarding_session: old_expired_session) }

      it 'cascades deletion to associated data (AC 2.4.3)' do
        parent_id = parent.id
        child_id = child.id
        insurance_id = insurance.id
        message_id = message.id

        expect {
          described_class.perform_now
        }.to change { OnboardingSession.count }.by(-1)
          .and change { Parent.count }.by(-1)
          .and change { Child.count }.by(-1)
          .and change { Insurance.count }.by(-1)
          .and change { Message.count }.by(-1)

        expect(Parent.exists?(parent_id)).to be false
        expect(Child.exists?(child_id)).to be false
        expect(Insurance.exists?(insurance_id)).to be false
        expect(Message.exists?(message_id)).to be false
      end

      it 'nullifies audit log references (preserves audit trail)' do
        audit_log = create(:audit_log, onboarding_session: old_expired_session)
        audit_log_id = audit_log.id

        expect {
          described_class.perform_now
        }.not_to change { AuditLog.where(id: audit_log_id).count }

        # Audit log still exists but session_id is nullified
        audit_log.reload
        expect(audit_log.onboarding_session_id).to be_nil
      end
    end

    context 'when no sessions need deletion' do
      it 'completes successfully with zero deletions' do
        result = described_class.perform_now
        expect(result).to eq(0)
      end

      it 'logs zero deletions' do
        allow(Rails.logger).to receive(:info)

        expect(Rails.logger).to receive(:info).with(include('Deleted 0 session(s)'))

        described_class.perform_now
      end
    end

    context 'with custom retention period' do
      let(:custom_retention_days) { 30 }

      before do
        allow(Rails.configuration).to receive(:data_retention_days).and_return(custom_retention_days)
      end

      let!(:old_expired_session) do
        create(:onboarding_session,
               status: :expired,
               updated_at: 31.days.ago)
      end

      it 'uses the configured retention period' do
        expect {
          described_class.perform_now
        }.to change { OnboardingSession.count }.by(-1)
      end

      it 'includes custom retention period in audit log' do
        old_session_id = old_expired_session.id

        described_class.perform_now

        audit_log = AuditLog.find_by(resource_id: old_session_id, action: 'SESSION_DELETED')
        expect(audit_log.details['retention_period_days']).to eq(30)
      end
    end

    context 'when an error occurs during deletion' do
      let!(:old_expired_session_1) do
        create(:onboarding_session,
               status: :expired,
               updated_at: 100.days.ago)
      end

      let!(:old_expired_session_2) do
        create(:onboarding_session,
               status: :expired,
               updated_at: 100.days.ago)
      end

      before do
        # Simulate error on first session only
        allow_any_instance_of(OnboardingSession).to receive(:destroy!)
          .and_wrap_original do |method, *args|
            if method.receiver.id == old_expired_session_1.id
              raise ActiveRecord::RecordNotDestroyed.new('Simulated error')
            else
              method.call(*args)
            end
          end
      end

      it 'continues processing other sessions after error' do
        expect(Rails.logger).to receive(:error).with(include("Failed to delete session #{old_expired_session_1.id}"))

        expect {
          described_class.perform_now
        }.not_to raise_error
      end

      it 'still deletes sessions that do not error' do
        expect {
          described_class.perform_now
        }.to change { OnboardingSession.count }.by(-1)

        # First session still exists due to error
        expect(OnboardingSession.exists?(old_expired_session_1.id)).to be true
        # Second session was deleted successfully
        expect(OnboardingSession.exists?(old_expired_session_2.id)).to be false
      end

      it 'returns count of successfully deleted sessions' do
        result = described_class.perform_now
        expect(result).to eq(1)
      end
    end

    context 'with many expired sessions past retention' do
      before do
        # Create 50 old expired sessions
        50.times do |i|
          create(:onboarding_session,
                 status: :expired,
                 updated_at: (100 + i).days.ago)
        end
      end

      it 'deletes all sessions in batch' do
        expect {
          described_class.perform_now
        }.to change { OnboardingSession.where(status: :expired).count }.by(-50)
      end

      it 'returns correct count for batch deletion' do
        result = described_class.perform_now
        expect(result).to eq(50)
      end

      it 'creates audit logs for all deleted sessions' do
        expect {
          described_class.perform_now
        }.to change { AuditLog.where(action: 'SESSION_DELETED').count }.by(50)
      end
    end

    context 'edge case: sessions at and near retention threshold' do
      # Use a fixed time reference for this test
      let(:test_time) { Time.zone.parse('2025-01-01 12:00:00') }
      let(:threshold_time) { test_time - 90.days }

      around do |example|
        travel_to(test_time) do
          example.run
        end
      end

      before do
        # Override the threshold for this test
        allow(Rails.configuration).to receive(:data_retention_days).and_return(90)
      end

      let!(:just_before_threshold_session) do
        # Session just NEWER than threshold (threshold + 1 hour)
        # This should NOT be deleted
        create(:onboarding_session, status: :expired).tap do |s|
          s.update_column(:updated_at, threshold_time + 1.hour)
        end
      end

      let!(:just_after_threshold_session) do
        # Session just OLDER than threshold (threshold - 1 hour)
        # This SHOULD be deleted
        create(:onboarding_session, status: :expired).tap do |s|
          s.update_column(:updated_at, threshold_time - 1.hour)
        end
      end

      it 'does not delete sessions newer than threshold' do
        just_before_id = just_before_threshold_session.id
        just_after_id = just_after_threshold_session.id

        expect {
          described_class.perform_now
        }.to change { OnboardingSession.count }.by(-1)

        # Session newer than threshold should still exist
        expect(OnboardingSession.exists?(just_before_id)).to be true
        # Session older than threshold should be deleted
        expect(OnboardingSession.exists?(just_after_id)).to be false
      end
    end

  end
end
