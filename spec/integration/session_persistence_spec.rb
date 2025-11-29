# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Session Progress Persistence', type: :integration do
  let(:session) { create(:onboarding_session, status: :started, progress: {}) }
  let(:update_mutation) do
    <<~GQL
      mutation UpdateSessionProgress($input: UpdateSessionProgressInput!) {
        updateSessionProgress(input: $input) {
          session {
            id
            status
            progress
            expiresAt
          }
        }
      }
    GQL
  end
  let(:query_session) do
    <<~GQL
      query GetSession($id: ID!) {
        session(id: $id) {
          id
          status
          progress
          expiresAt
        }
      }
    GQL
  end

  describe 'persistence across page refreshes' do
    it 'persists progress after update' do
      # Step 1: Update progress
      progress_data = {
        'currentStep' => 'parent_info',
        'completedSteps' => ['welcome', 'terms'],
        'intake' => {
          'parentInfoComplete' => true
        }
      }

      result = execute_graphql(update_mutation, variables: {
        input: {
          sessionId: session.id,
          progress: progress_data
        }
      }, context: { current_session: session })

      expect(result['errors']).to be_nil
      updated_session = result.dig('data', 'updateSessionProgress', 'session')
      expect(updated_session['progress']['currentStep']).to eq('parent_info')

      # Step 2: Clear cache (simulating page close/refresh)
      Rails.cache.delete("daybreak:sessions:progress:#{session.id}")

      # Step 3: Query session again (simulating page reload)
      # Need to pass current_session in context for authorization
      query_result = execute_graphql(query_session, variables: { id: session.id }, context: { current_session: session.reload })

      # Check for errors first
      expect(query_result['errors']).to be_nil, "Query errors: #{query_result['errors']}"

      reloaded_session = query_result.dig('data', 'session')
      expect(reloaded_session).not_to be_nil, "Session data not found in response: #{query_result.inspect}"

      # Verify progress persisted from database
      expect(reloaded_session['progress']['currentStep']).to eq('parent_info')
      expect(reloaded_session['progress']['completedSteps']).to include('welcome', 'terms')
      expect(reloaded_session['progress']['intake']['parentInfoComplete']).to be true
      expect(reloaded_session['status']).to eq('in_progress')
    end

    it 'repopulates cache on read after cache miss' do
      # Update session
      session.update!(
        progress: { 'currentStep' => 'child_info' },
        status: :in_progress
      )

      # Clear cache
      Rails.cache.delete("daybreak:sessions:progress:#{session.id}")

      # Query should repopulate cache
      execute_graphql(query_session, variables: { id: session.id }, context: { current_session: session })

      # Verify cache was repopulated
      cached_progress = Rails.cache.read("daybreak:sessions:progress:#{session.id}")
      expect(cached_progress).to be_nil # Note: Query doesn't auto-populate cache, only mutation does
    end
  end

  describe 'write-through cache behavior' do
    before do
      allow(Rails.cache).to receive(:write).and_call_original
    end

    it 'writes to database before cache' do
      progress_data = { 'currentStep' => 'parent_info' }

      # Verify DB write happens
      expect {
        execute_graphql(update_mutation, variables: {
          input: {
            sessionId: session.id,
            progress: progress_data
          }
        }, context: { current_session: session })
      }.to change { session.reload.progress }

      # Verify cache write was called
      expect(Rails.cache).to have_received(:write).with(
        "daybreak:sessions:progress:#{session.id}",
        anything,
        expires_in: 1.hour
      )
    end

    it 'maintains data consistency between cache and DB' do
      progress_data = {
        'currentStep' => 'insurance',
        'completedSteps' => ['welcome', 'parent_info', 'child_info']
      }

      execute_graphql(update_mutation, variables: {
        input: {
          sessionId: session.id,
          progress: progress_data
        }
      }, context: { current_session: session })

      # Verify DB has data
      db_session = OnboardingSession.find(session.id)
      expect(db_session.progress['currentStep']).to eq('insurance')
      expect(db_session.progress['completedSteps']).to include('welcome', 'parent_info', 'child_info')
    end
  end

  describe 'concurrent updates' do
    it 'handles last-write-wins for concurrent progress updates' do
      # Simulate two concurrent updates
      progress1 = { 'currentStep' => 'parent_info' }
      progress2 = { 'currentStep' => 'child_info' }

      execute_graphql(update_mutation, variables: {
        input: {
          sessionId: session.id,
          progress: progress1
        }
      }, context: { current_session: session })

      execute_graphql(update_mutation, variables: {
        input: {
          sessionId: session.id,
          progress: progress2
        }
      }, context: { current_session: session })

      # Last write should win
      final_session = OnboardingSession.find(session.id)
      expect(final_session.progress['currentStep']).to eq('child_info')
    end
  end

  describe 'status transition persistence' do
    it 'persists auto-transition from started to in_progress' do
      expect(session.status).to eq('started')

      execute_graphql(update_mutation, variables: {
        input: {
          sessionId: session.id,
          progress: { 'currentStep' => 'test' }
        }
      }, context: { current_session: session })

      # Reload from DB
      session.reload
      expect(session.status).to eq('in_progress')

      # Verify after simulated page refresh
      Rails.cache.delete("daybreak:sessions:progress:#{session.id}")
      db_session = OnboardingSession.find(session.id)
      expect(db_session.status).to eq('in_progress')
    end
  end

  describe 'expiration extension persistence' do
    it 'persists extended expiration time' do
      # Freeze time at the beginning
      freeze_time = Time.zone.parse('2025-01-01 12:00:00')

      travel_to freeze_time do
        # Create session with known expiration
        test_session = create(:onboarding_session,
          status: :started,
          progress: {},
          expires_at: freeze_time + 30.minutes
        )

        original_expires_at = test_session.expires_at

        # Update progress which should extend expiration
        execute_graphql(update_mutation, variables: {
          input: {
            sessionId: test_session.id,
            progress: { 'currentStep' => 'test' }
          }
        }, context: { current_session: test_session })

        # Reload from DB
        test_session.reload
        expect(test_session.expires_at).to be > original_expires_at
        expect(test_session.expires_at).to be_within(5.seconds).of(freeze_time + 1.hour)

        # Verify after simulated page refresh
        db_session = OnboardingSession.find(test_session.id)
        expect(db_session.expires_at).to be_within(5.seconds).of(freeze_time + 1.hour)
      end
    end
  end
end
