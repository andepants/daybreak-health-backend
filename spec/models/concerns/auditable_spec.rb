# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auditable, type: :model do
  # Create a test model class that includes the concern
  before(:all) do
    ActiveRecord::Migration.create_table :test_auditables, id: :uuid, force: true do |t|
      t.uuid :onboarding_session_id
      t.string :name
      t.text :secret_data
      t.timestamps
    end

    class TestAuditable < ApplicationRecord
      include Encryptable
      include Auditable

      belongs_to :onboarding_session, optional: true

      encrypts :secret_data, deterministic: false
    end
  end

  after(:all) do
    ActiveRecord::Migration.drop_table :test_auditables
    Object.send(:remove_const, :TestAuditable)
  end

  let(:session) { create(:onboarding_session) }

  describe 'audit logging' do
    context 'on create' do
      it 'creates an audit log entry' do
        # Create session first (it will create its own audit log)
        test_session = create(:onboarding_session)
        # Now count audit logs before creating TestAuditable
        initial_count = AuditLog.count

        TestAuditable.create!(
          name: 'Test',
          onboarding_session: test_session
        )

        # Should have created one audit log for TestAuditable
        expect(AuditLog.count).to eq(initial_count + 1)
      end

      it 'logs the CREATE action' do
        record = TestAuditable.create!(
          name: 'Test',
          onboarding_session: session
        )

        # Find the audit log for TestAuditable (not OnboardingSession)
        audit = AuditLog.where(resource: 'TestAuditable', resource_id: record.id).last
        expect(audit.action).to eq('CREATE')
        expect(audit.resource).to eq('TestAuditable')
        expect(audit.resource_id).to eq(record.id)
      end

      it 'includes the session ID' do
        record = TestAuditable.create!(
          name: 'Test',
          onboarding_session: session
        )

        # Find the audit log for TestAuditable (not OnboardingSession)
        audit = AuditLog.where(resource: 'TestAuditable', resource_id: record.id).last
        expect(audit.onboarding_session_id).to eq(session.id)
      end
    end

    context 'on update' do
      it 'creates an audit log entry' do
        record = TestAuditable.create!(name: 'Original', onboarding_session: session)

        expect {
          record.update!(name: 'Updated')
        }.to change(AuditLog, :count).by(1)
      end

      it 'logs the UPDATE action' do
        record = TestAuditable.create!(name: 'Original', onboarding_session: session)
        initial_count = AuditLog.count
        record.update!(name: 'Updated')

        # Should have created one more audit log
        expect(AuditLog.count).to eq(initial_count + 1)

        # The last one should be the UPDATE
        audit = AuditLog.order(created_at: :desc).first
        expect(audit.action).to eq('UPDATE')
      end

      it 'does not log if no changes were made' do
        record = TestAuditable.create!(name: 'Test', onboarding_session: session)

        expect {
          record.update!(name: 'Test') # Same value
        }.not_to change(AuditLog, :count)
      end
    end

    context 'on destroy' do
      it 'creates an audit log entry' do
        record = TestAuditable.create!(name: 'Test', onboarding_session: session)

        expect {
          record.destroy!
        }.to change(AuditLog, :count).by(1)
      end

      it 'logs the DELETE action' do
        record = TestAuditable.create!(name: 'Test', onboarding_session: session)
        initial_count = AuditLog.count
        record.destroy!

        expect(AuditLog.count).to eq(initial_count + 1)
        audit = AuditLog.order(created_at: :desc).first
        expect(audit.action).to eq('DELETE')
      end
    end
  end

  describe 'PHI-safe logging' do
    it 'redacts encrypted fields in change logs' do
      record = TestAuditable.create!(
        name: 'Test',
        secret_data: 'sensitive information',
        onboarding_session: session
      )

      audit = AuditLog.last
      changes = audit.details['changes']

      # Secret data should be redacted
      expect(changes).to be_present
      expect(changes.to_s).not_to include('sensitive information')
    end

    it 'logs non-PHI fields normally' do
      record = TestAuditable.create!(
        name: 'Test Name',
        onboarding_session: session
      )

      # Find the audit log for TestAuditable (not OnboardingSession)
      audit = AuditLog.where(resource: 'TestAuditable', resource_id: record.id).last
      changes = audit.details['changes']

      # Name is not encrypted, should be logged
      expect(changes['name']).to be_present
    end
  end

  describe 'error handling' do
    it 'does not prevent record creation if audit logging fails' do
      # Stub AuditLog.create! to raise an error
      allow(AuditLog).to receive(:create!).and_raise(StandardError, 'Audit failed')

      # Record should still be created
      expect {
        TestAuditable.create!(name: 'Test', onboarding_session: session)
      }.not_to raise_error
    end

    it 'logs audit failures' do
      allow(AuditLog).to receive(:create!).and_raise(StandardError, 'Audit failed')

      # Expect at least one error log (might be more due to OnboardingSession also having Auditable)
      expect(Rails.logger).to receive(:error).with(/Audit logging failed/).at_least(:once)

      TestAuditable.create!(name: 'Test', onboarding_session: session)
    end
  end

  describe 'context tracking' do
    # Clean thread locals after each test to prevent cascading failures
    after do
      Thread.current[:current_session] = nil
      Thread.current[:current_user] = nil
      Thread.current[:current_ip_address] = nil
      Thread.current[:current_user_agent] = nil
    end

    it 'uses Thread.current for session ID if not an association' do
      Thread.current[:current_session] = session

      # Create without association
      record = TestAuditable.create!(name: 'Test')

      # Find the audit log for TestAuditable (not OnboardingSession)
      audit = AuditLog.where(resource: 'TestAuditable', resource_id: record.id).last
      expect(audit.onboarding_session_id).to eq(session.id)
    end

    it 'uses Thread.current for user ID' do
      user_uuid = SecureRandom.uuid
      Thread.current[:current_user] = { id: user_uuid }

      record = TestAuditable.create!(name: 'Test', onboarding_session: session)

      # Find the audit log for TestAuditable (not OnboardingSession)
      audit = AuditLog.where(resource: 'TestAuditable', resource_id: record.id).last
      expect(audit.user_id).to eq(user_uuid)
    end

    it 'uses Thread.current for IP address' do
      Thread.current[:current_ip_address] = '192.168.1.1'

      record = TestAuditable.create!(name: 'Test', onboarding_session: session)

      # Find the audit log for TestAuditable (not OnboardingSession)
      audit = AuditLog.where(resource: 'TestAuditable', resource_id: record.id).last
      expect(audit.ip_address).to eq('192.168.1.1')
    end

    it 'uses Thread.current for user agent' do
      Thread.current[:current_user_agent] = 'Mozilla/5.0'

      record = TestAuditable.create!(name: 'Test', onboarding_session: session)

      # Find the audit log for TestAuditable (not OnboardingSession)
      audit = AuditLog.where(resource: 'TestAuditable', resource_id: record.id).last
      expect(audit.user_agent).to eq('Mozilla/5.0')
    end
  end
end
