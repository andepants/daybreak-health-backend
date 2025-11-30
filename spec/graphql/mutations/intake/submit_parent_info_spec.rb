# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Intake::SubmitParentInfo, type: :graphql do
  let(:session) { create(:onboarding_session, status: :in_progress) }
  let(:session_id) { "sess_#{session.id.gsub('-', '')}" }

  let(:valid_parent_info) do
    {
      firstName: 'Sarah',
      lastName: 'Johnson',
      email: 'sarah.johnson@example.com',
      phone: '+12025551234',
      relationship: 'parent',
      isGuardian: true
    }
  end

  let(:mutation) do
    <<~GQL
      mutation SubmitParentInfo($sessionId: ID!, $parentInfo: ParentInput!) {
        submitParentInfo(sessionId: $sessionId, parentInfo: $parentInfo) {
          parent {
            id
            firstName
            lastName
            email
            phone
            relationship
            isGuardian
          }
          errors
        }
      }
    GQL
  end

  describe 'successful submission' do
    it 'creates a parent record' do
      expect {
        execute_graphql(
          mutation,
          variables: {
            sessionId: session_id,
            parentInfo: valid_parent_info
          }
        )
      }.to change(Parent, :count).by(1)
    end

    it 'returns parent data' do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          parentInfo: valid_parent_info
        }
      )

      data = result['data']['submitParentInfo']

      expect(data['errors']).to be_empty
      expect(data['parent']).to be_present
      expect(data['parent']['firstName']).to eq('Sarah')
      expect(data['parent']['lastName']).to eq('Johnson')
      expect(data['parent']['email']).to eq('sarah.johnson@example.com')
      expect(data['parent']['phone']).to eq('+12025551234')
      expect(data['parent']['relationship']).to eq('parent')
      expect(data['parent']['isGuardian']).to eq(true)
    end

    it 'encrypts PHI fields' do
      execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          parentInfo: valid_parent_info
        }
      )

      parent = Parent.last
      # Query raw database to verify encryption
      raw_data = ActiveRecord::Base.connection.execute(
        "SELECT email, phone, first_name, last_name FROM parents WHERE id = '#{parent.id}'"
      ).first

      # Raw data should NOT match decrypted values
      expect(raw_data['email']).not_to eq('sarah.johnson@example.com')
      expect(raw_data['phone']).not_to eq('+12025551234')
      expect(raw_data['first_name']).not_to eq('Sarah')
      expect(raw_data['last_name']).not_to eq('Johnson')

      # Decrypted data should match
      expect(parent.email).to eq('sarah.johnson@example.com')
      expect(parent.phone).to eq('+12025551234')
    end

    it 'updates session progress' do
      execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          parentInfo: valid_parent_info
        }
      )

      session.reload
      expect(session.progress.dig('intake', 'parentInfoCollected')).to eq(true)
    end

    it 'extends session expiration' do
      execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          parentInfo: valid_parent_info
        }
      )

      session.reload
      # Session should be extended to ~1 hour from now
      expect(session.expires_at).to be_within(5.seconds).of(1.hour.from_now)
    end

    it 'creates audit log entry' do
      execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          parentInfo: valid_parent_info
        }
      )

      # Find the PARENT_INFO_SUBMITTED audit log (not CREATE logs from Auditable concern)
      audit_log = AuditLog.find_by(action: 'PARENT_INFO_SUBMITTED')
      expect(audit_log).to be_present
      expect(audit_log.resource).to eq('Parent')
      expect(audit_log.details['has_email']).to eq(true)
      expect(audit_log.details['has_phone']).to eq(true)
    end

    it 'queues recovery email job' do
      expect {
        execute_graphql(
          mutation,
          variables: {
            sessionId: session_id,
            parentInfo: valid_parent_info
          }
        )
      }.to have_enqueued_job(SessionRecoveryEmailJob).with(session.id, 'sarah.johnson@example.com')
    end
  end

  describe 'validation failures' do
    it 'rejects invalid email format' do
      invalid_info = valid_parent_info.merge(email: 'not-an-email')

      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          parentInfo: invalid_info
        }
      )

      data = result['data']['submitParentInfo']

      expect(data['parent']).to be_nil
      expect(data['errors']).to include(match(/Email must be in valid RFC 5322 format/i))
    end

    it 'rejects invalid phone format' do
      invalid_info = valid_parent_info.merge(phone: '123')

      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          parentInfo: invalid_info
        }
      )

      data = result['data']['submitParentInfo']

      expect(data['parent']).to be_nil
      expect(data['errors']).to include(match(/Phone number must be in valid E.164 format/i))
    end

    it 'rejects invalid relationship' do
      invalid_info = valid_parent_info.merge(relationship: 'invalid_relation')

      result = execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          parentInfo: invalid_info
        }
      )

      data = result['data']['submitParentInfo']

      expect(data['parent']).to be_nil
      expect(data['errors']).to include(match(/Relationship must be one of:/i))
    end

    it 'rejects non-existent session' do
      result = execute_graphql(
        mutation,
        variables: {
          sessionId: 'sess_nonexistent',
          parentInfo: valid_parent_info
        }
      )

      data = result['data']['submitParentInfo']

      expect(data['parent']).to be_nil
      expect(data['errors']).to include('Session not found')
    end

    it 'rejects expired session' do
      expired_session = create(:onboarding_session, status: :in_progress, expires_at: 1.hour.ago)
      expired_session_id = "sess_#{expired_session.id.gsub('-', '')}"

      result = execute_graphql(
        mutation,
        variables: {
          sessionId: expired_session_id,
          parentInfo: valid_parent_info
        }
      )

      data = result['data']['submitParentInfo']

      expect(data['parent']).to be_nil
      expect(data['errors']).to include('Session has expired')
    end
  end

  describe 'phone normalization' do
    it 'normalizes US phone numbers to E.164 format' do
      unnormalized_info = valid_parent_info.merge(phone: '(202) 555-1234')

      execute_graphql(
        mutation,
        variables: {
          sessionId: session_id,
          parentInfo: unnormalized_info
        }
      )

      parent = Parent.last
      expect(parent.phone).to eq('+12025551234')
    end
  end
end
