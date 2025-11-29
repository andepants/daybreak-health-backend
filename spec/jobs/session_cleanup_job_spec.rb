# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionCleanupJob, type: :job do
  describe '#perform' do
    let!(:active_not_expired) do
      create(:onboarding_session, status: :in_progress, expires_at: 1.hour.from_now)
    end

    let!(:active_expired) do
      create(:onboarding_session, status: :in_progress, expires_at: 1.hour.ago)
    end

    let!(:started_expired) do
      create(:onboarding_session, status: :started, expires_at: 2.hours.ago)
    end

    let!(:already_expired) do
      create(:onboarding_session, status: :expired, expires_at: 3.hours.ago)
    end

    let!(:abandoned_expired) do
      create(:onboarding_session, status: :abandoned, expires_at: 1.hour.ago)
    end

    let!(:submitted_expired) do
      create(:onboarding_session, status: :submitted, expires_at: 1.hour.ago)
    end

    it 'marks expired active sessions as expired' do
      expect {
        described_class.perform_now
      }.to change { active_expired.reload.status }.from('in_progress').to('expired')
        .and change { started_expired.reload.status }.from('started').to('expired')
    end

    it 'does not modify non-expired sessions' do
      expect {
        described_class.perform_now
      }.not_to change { active_not_expired.reload.status }
    end

    it 'does not modify already expired sessions' do
      expect {
        described_class.perform_now
      }.not_to change { already_expired.reload.status }
    end

    it 'does not modify abandoned sessions even if expired' do
      expect {
        described_class.perform_now
      }.not_to change { abandoned_expired.reload.status }
    end

    it 'does not modify submitted sessions even if expired' do
      expect {
        described_class.perform_now
      }.not_to change { submitted_expired.reload.status }
    end

    it 'creates audit log entries for each expired session' do
      described_class.perform_now

      # Check specifically for SESSION_EXPIRED audit logs (not UPDATE logs from Auditable)
      audit_logs = AuditLog.where(action: 'SESSION_EXPIRED')
      expect(audit_logs.count).to eq(2)
      expect(audit_logs.pluck(:resource_id)).to match_array([active_expired.id, started_expired.id])
    end

    it 'includes required details in audit log' do
      described_class.perform_now

      audit_log = AuditLog.find_by(resource_id: active_expired.id, action: 'SESSION_EXPIRED')
      expect(audit_log).to be_present
      expect(audit_log.details).to include('expired_at', 'expires_at')
      expect(audit_log.details['previous_status']).to be_present
    end

    it 'logs the count of expired sessions' do
      allow(Rails.logger).to receive(:info)

      expect(Rails.logger).to receive(:info).with(include('Starting session expiration check'))
      expect(Rails.logger).to receive(:info).with(include('Completed'))

      described_class.perform_now
    end

    it 'returns the count of expired sessions' do
      result = described_class.perform_now
      expect(result).to eq(2)
    end

    context 'when an error occurs during expiration' do
      before do
        allow_any_instance_of(OnboardingSession).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'continues processing other sessions' do
        expect(Rails.logger).to receive(:error).at_least(:once)

        # Should not raise, should complete
        expect {
          described_class.perform_now
        }.not_to raise_error
      end

      it 'returns count of successfully expired sessions' do
        result = described_class.perform_now
        expect(result).to eq(0) # None succeeded due to error
      end
    end

    context 'with many expired sessions' do
      before do
        # Create 50 additional expired sessions
        50.times do
          create(:onboarding_session, status: :in_progress, expires_at: 1.hour.ago)
        end
      end

      it 'expires all sessions in batch' do
        expect {
          described_class.perform_now
        }.to change { OnboardingSession.where(status: :expired).count }.by(52) # 50 + 2 original
      end
    end
  end
end
