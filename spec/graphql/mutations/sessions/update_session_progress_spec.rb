# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Sessions::UpdateSessionProgress, type: :graphql do
  let(:mutation) do
    <<~GQL
      mutation UpdateSessionProgress($input: UpdateSessionProgressInput!) {
        updateSessionProgress(input: $input) {
          session {
            id
            status
            progress
            updatedAt
            expiresAt
          }
        }
      }
    GQL
  end

  let(:session) { create(:onboarding_session, status: initial_status, progress: initial_progress) }
  let(:variables) do
    {
      input: {
        sessionId: session.id,
        progress: new_progress
      }
    }
  end

  describe 'successful progress update' do
    let(:initial_status) { :started }
    let(:initial_progress) { { 'currentStep' => 'welcome', 'completedSteps' => [] } }
    let(:new_progress) { { 'currentStep' => 'parent_info', 'completedSteps' => ['welcome'] } }

    before do
      # Enable caching for this test
      allow(Rails.cache).to receive(:write).and_call_original
    end

    it 'updates the session progress' do
      result = execute_graphql(mutation, variables: variables)
      data = result.dig('data', 'updateSessionProgress', 'session')

      expect(data['progress']['currentStep']).to eq('parent_info')
      expect(data['progress']['completedSteps']).to include('welcome')
    end

    it 'merges progress with existing data' do
      session.update!(progress: { 'currentStep' => 'welcome', 'intake' => { 'started' => true } })

      result = execute_graphql(mutation, variables: {
        input: {
          sessionId: session.id,
          progress: { 'currentStep' => 'parent_info' }
        }
      })

      data = result.dig('data', 'updateSessionProgress', 'session')
      expect(data['progress']['intake']['started']).to be true
    end

    it 'auto-transitions from started to in_progress' do
      result = execute_graphql(mutation, variables: variables)
      data = result.dig('data', 'updateSessionProgress', 'session')

      expect(data['status']).to eq('in_progress')
    end

    it 'updates the updatedAt timestamp' do
      original_updated_at = session.updated_at

      travel_to 1.minute.from_now do
        result = execute_graphql(mutation, variables: variables)
        data = result.dig('data', 'updateSessionProgress', 'session')

        expect(Time.parse(data['updatedAt'])).to be > original_updated_at
      end
    end

    it 'extends the expiresAt by 1 hour' do
      # Set initial expiration to 30 minutes to test extension
      session.update!(expires_at: 30.minutes.from_now)

      result = execute_graphql(mutation, variables: variables)
      data = result.dig('data', 'updateSessionProgress', 'session')

      new_expires_at = Time.parse(data['expiresAt'])
      # Should be set to 1 hour from now (current time + 1 hour)
      expect(new_expires_at).to be_within(5.seconds).of(Time.current + 1.hour)
      # Should be greater than the 30 minute expiration we set
      expect(new_expires_at).to be > session.reload.expires_at - 35.minutes
    end

    it 'writes progress to cache' do
      expect(Rails.cache).to receive(:write).with(
        "daybreak:sessions:progress:#{session.id}",
        anything,
        expires_in: 1.hour
      )

      execute_graphql(mutation, variables: variables)
    end

    it 'creates an audit log entry' do
      initial_count = AuditLog.count

      execute_graphql(mutation, variables: variables)

      # Should create at least 1 audit log for the update
      expect(AuditLog.count).to be > initial_count

      # Find the UPDATE audit log for this session (not the CREATE from session creation)
      audit_log = AuditLog.where(
        resource: 'OnboardingSession',
        resource_id: session.id,
        action: 'UPDATE'
      ).last

      expect(audit_log).to be_present
      expect(audit_log.resource_id).to eq(session.id)
    end

    it 'triggers sessionUpdated subscription' do
      expect(DaybreakHealthBackendSchema.subscriptions).to receive(:trigger).with(
        'sessionUpdated',
        { session_id: session.id.to_s },
        anything
      )

      execute_graphql(mutation, variables: variables)
    end
  end

  describe 'with in_progress session' do
    let(:initial_status) { :in_progress }
    let(:initial_progress) { { 'currentStep' => 'parent_info', 'completedSteps' => ['welcome'] } }
    let(:new_progress) { { 'currentStep' => 'child_info', 'completedSteps' => ['parent_info'] } }

    it 'updates progress without changing status' do
      result = execute_graphql(mutation, variables: variables)
      data = result.dig('data', 'updateSessionProgress', 'session')

      expect(data['status']).to eq('in_progress')
      expect(data['progress']['currentStep']).to eq('child_info')
    end
  end

  describe 'error cases' do
    let(:initial_status) { :started }
    let(:initial_progress) { {} }
    let(:new_progress) { { 'currentStep' => 'test' } }

    context 'with non-existent session' do
      let(:variables) do
        {
          input: {
            sessionId: SecureRandom.uuid,
            progress: new_progress
          }
        }
      end

      it 'returns an error' do
        result = execute_graphql(mutation, variables: variables)
        errors = result['errors']

        expect(errors).to be_present
        expect(errors.first['message']).to include('Session not found')
      end
    end

    context 'with abandoned session' do
      let(:initial_status) { :abandoned }

      it 'returns an error' do
        result = execute_graphql(mutation, variables: variables)
        errors = result['errors']

        expect(errors).to be_present
        expect(errors.first['message']).to include('abandoned')
      end
    end

    context 'with expired session' do
      let(:initial_status) { :expired }

      it 'returns an error' do
        result = execute_graphql(mutation, variables: variables)
        errors = result['errors']

        expect(errors).to be_present
        expect(errors.first['message']).to include('Session is not active')
      end
    end

    context 'with session past expiration time' do
      let(:initial_status) { :in_progress }

      before do
        session.update!(expires_at: 1.hour.ago)
      end

      it 'returns SESSION_EXPIRED error code' do
        result = execute_graphql(mutation, variables: variables)
        errors = result['errors']

        expect(errors).to be_present
        expect(errors.first['message']).to eq('Session has expired')
        expect(errors.first['extensions']['code']).to eq('SESSION_EXPIRED')
      end

      it 'does not update the session' do
        original_progress = session.progress

        execute_graphql(mutation, variables: variables)

        expect(session.reload.progress).to eq(original_progress)
      end
    end

    context 'with submitted session' do
      let(:initial_status) { :submitted }

      it 'returns an error' do
        result = execute_graphql(mutation, variables: variables)
        errors = result['errors']

        expect(errors).to be_present
        expect(errors.first['message']).to include('Session is not active')
      end
    end

    context 'with invalid progress structure' do
      let(:new_progress) { 'not a hash' }

      it 'returns a validation error' do
        result = execute_graphql(mutation, variables: variables)
        errors = result['errors']

        expect(errors).to be_present
      end
    end

    context 'with blank currentStep' do
      let(:new_progress) { { 'currentStep' => '' } }

      it 'returns a validation error' do
        result = execute_graphql(mutation, variables: variables)
        errors = result['errors']

        expect(errors).to be_present
        expect(errors.first['message']).to include('currentStep cannot be blank')
      end
    end

    context 'with invalid completedSteps type' do
      let(:new_progress) { { 'completedSteps' => 'not an array' } }

      it 'returns a validation error' do
        result = execute_graphql(mutation, variables: variables)
        errors = result['errors']

        expect(errors).to be_present
        expect(errors.first['message']).to include('completedSteps must be an array')
      end
    end
  end

  describe 'completedSteps array handling' do
    let(:initial_status) { :in_progress }
    let(:initial_progress) { { 'completedSteps' => ['welcome', 'terms'] } }
    let(:new_progress) { { 'completedSteps' => ['terms', 'privacy'] } }

    it 'merges arrays and removes duplicates' do
      result = execute_graphql(mutation, variables: variables)
      data = result.dig('data', 'updateSessionProgress', 'session')

      expect(data['progress']['completedSteps']).to contain_exactly('welcome', 'terms', 'privacy')
    end
  end

  describe 'deep merge behavior' do
    let(:initial_status) { :in_progress }
    let(:initial_progress) do
      {
        'intake' => {
          'parentInfo' => { 'complete' => true },
          'childInfo' => { 'complete' => false }
        }
      }
    end
    let(:new_progress) do
      {
        'intake' => {
          'childInfo' => { 'complete' => true }
        }
      }
    end

    it 'deep merges nested objects' do
      result = execute_graphql(mutation, variables: variables)
      data = result.dig('data', 'updateSessionProgress', 'session')

      expect(data['progress']['intake']['parentInfo']['complete']).to be true
      expect(data['progress']['intake']['childInfo']['complete']).to be true
    end
  end
end
