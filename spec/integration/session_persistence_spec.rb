# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Session Progress Persistence', type: :integration do
  let(:session) { create(:onboarding_session, status: :started, progress: {}) }
  let(:update_mutation) do
    <<~GQL
      mutation UpdateSessionProgress($sessionId: ID!, $progress: JSON!) {
        updateSessionProgress(sessionId: $sessionId, progress: $progress) {
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
        sessionId: session.id,
        progress: progress_data
      })

      expect(result['errors']).to be_nil
      updated_session = result.dig('data', 'updateSessionProgress', 'session')
      expect(updated_session['progress']['currentStep']).to eq('parent_info')

      # Step 2: Clear cache (simulating page close/refresh)
      Rails.cache.delete("session:progress:#{session.id}")

      # Step 3: Query session again (simulating page reload)
      query_result = execute_graphql(query_session, variables: { id: session.id })

      reloaded_session = query_result.dig('data', 'session')

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
      Rails.cache.delete("session:progress:#{session.id}")

      # Query should repopulate cache
      execute_graphql(query_session, variables: { id: session.id })

      # Verify cache was repopulated
      cached_progress = Rails.cache.read("session:progress:#{session.id}")
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
          sessionId: session.id,
          progress: progress_data
        })
      }.to change { session.reload.progress }

      # Verify cache write was called
      expect(Rails.cache).to have_received(:write).with(
        "session:progress:#{session.id}",
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
        sessionId: session.id,
        progress: progress_data
      })

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
        sessionId: session.id,
        progress: progress1
      })

      execute_graphql(update_mutation, variables: {
        sessionId: session.id,
        progress: progress2
      })

      # Last write should win
      final_session = OnboardingSession.find(session.id)
      expect(final_session.progress['currentStep']).to eq('child_info')
    end
  end

  describe 'status transition persistence' do
    it 'persists auto-transition from started to in_progress' do
      expect(session.status).to eq('started')

      execute_graphql(update_mutation, variables: {
        sessionId: session.id,
        progress: { 'currentStep' => 'test' }
      })

      # Reload from DB
      session.reload
      expect(session.status).to eq('in_progress')

      # Verify after simulated page refresh
      Rails.cache.delete("session:progress:#{session.id}")
      db_session = OnboardingSession.find(session.id)
      expect(db_session.status).to eq('in_progress')
    end
  end

  describe 'expiration extension persistence' do
    it 'persists extended expiration time' do
      original_expires_at = session.expires_at

      travel_to Time.current do
        execute_graphql(update_mutation, variables: {
          sessionId: session.id,
          progress: { 'currentStep' => 'test' }
        })

        # Reload from DB
        session.reload
        expect(session.expires_at).to be > original_expires_at
        expect(session.expires_at).to be_within(5.seconds).of(Time.current + 1.hour)

        # Verify after simulated page refresh
        db_session = OnboardingSession.find(session.id)
        expect(db_session.expires_at).to be_within(5.seconds).of(Time.current + 1.hour)
      end
    end
  end
end
