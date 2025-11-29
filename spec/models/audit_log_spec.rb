# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditLog, type: :model do
  describe 'associations' do
    it { should belong_to(:onboarding_session).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:action) }
    it { should validate_presence_of(:resource) }
  end

  describe 'scopes' do
    let(:session) { create(:onboarding_session) }
    let!(:session_log) { create(:audit_log, onboarding_session: session) }
    let!(:other_log) { create(:audit_log, onboarding_session: nil) }
    let!(:old_log) { create(:audit_log, created_at: 1.day.ago) }

    describe '.for_session' do
      it 'returns logs for specific session' do
        expect(AuditLog.for_session(session.id)).to include(session_log)
        expect(AuditLog.for_session(session.id)).not_to include(other_log)
      end
    end

    describe '.recent' do
      it 'orders logs by created_at descending' do
        recent_logs = AuditLog.recent
        expect(recent_logs.first.created_at).to be > recent_logs.last.created_at
      end
    end
  end

  describe 'UUID primary key' do
    it 'generates UUID for id' do
      audit_log = create(:audit_log)
      expect(audit_log.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end

  describe 'timestamps' do
    it 'sets created_at' do
      audit_log = create(:audit_log)
      expect(audit_log.created_at).to be_present
    end

    it 'does not have updated_at' do
      audit_log = create(:audit_log)
      expect(audit_log).not_to respond_to(:updated_at)
    end
  end
end
