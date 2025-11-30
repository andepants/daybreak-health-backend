# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'supportRequests query', type: :graphql do
  let(:session) { create(:onboarding_session) }
  let(:session_id_prefixed) { "sess_#{session.id.gsub('-', '')}" }
  let!(:support_request1) do
    create(:support_request,
           onboarding_session: session,
           source: 'insurance-verification',
           resolved: false)
  end
  let!(:support_request2) do
    create(:support_request,
           onboarding_session: session,
           source: 'welcome-screen',
           resolved: true)
  end

  let(:query) do
    <<~GQL
      query SupportRequests($sessionId: ID!) {
        supportRequests(sessionId: $sessionId) {
          id
          sessionId
          intercomConversationId
          source
          resolved
          createdAt
          updatedAt
        }
      }
    GQL
  end

  describe 'successful query' do
    let(:context) do
      {
        current_user: { session_id: session.id, role: 'parent' },
        current_session: session
      }
    end

    it 'returns support requests for the session' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session.id },
        context: context
      )

      data = result.dig('data', 'supportRequests')
      expect(data).to be_present
      expect(data.length).to eq(2)
    end

    it 'returns support requests in recent order' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session.id },
        context: context
      )

      data = result.dig('data', 'supportRequests')
      # Most recent first
      expect(data.first['id']).to eq(support_request2.id.to_s)
      expect(data.last['id']).to eq(support_request1.id.to_s)
    end

    it 'includes all support request fields' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session.id },
        context: context
      )

      request_data = result.dig('data', 'supportRequests', 0)
      expect(request_data['id']).to be_present
      expect(request_data['sessionId']).to eq(session.id)
      expect(request_data['intercomConversationId']).to be_present
      expect(request_data['source']).to be_present
      expect(request_data['resolved']).to be_in([true, false])
      expect(request_data['createdAt']).to be_present
      expect(request_data['updatedAt']).to be_present
    end

    it 'accepts UUID format session ID' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session.id },
        context: context
      )

      data = result.dig('data', 'supportRequests')
      expect(data).to be_present
      expect(data.length).to eq(2)
    end

    it 'accepts sess_ prefixed session ID' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      data = result.dig('data', 'supportRequests')
      expect(data).to be_present
      expect(data.length).to eq(2)
    end

    it 'returns empty array when no support requests exist' do
      new_session = create(:onboarding_session)
      context_new = {
        current_user: { session_id: new_session.id, role: 'parent' },
        current_session: new_session
      }

      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: new_session.id },
        context: context_new
      )

      data = result.dig('data', 'supportRequests')
      expect(data).to eq([])
    end
  end

  describe 'authorization' do
    context 'when user is the session owner' do
      let(:context) do
        {
          current_user: { session_id: session.id, role: 'parent' },
          current_session: session
        }
      end

      it 'allows access' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        expect(result['errors']).to be_nil
        expect(result.dig('data', 'supportRequests')).to be_present
      end
    end

    context 'when user is an admin' do
      let(:context) do
        {
          current_user: { session_id: 'different-id', role: 'admin' }
        }
      end

      it 'allows access' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        expect(result['errors']).to be_nil
        expect(result.dig('data', 'supportRequests')).to be_present
      end
    end

    context 'when user is not the session owner' do
      let(:other_session) { create(:onboarding_session) }
      let(:context) do
        {
          current_user: { session_id: other_session.id, role: 'parent' },
          current_session: other_session
        }
      end

      it 'denies access' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        expect(result['errors']).to be_present
        expect(result['errors'].first['message']).to eq('Access denied')
        expect(result['errors'].first['extensions']['code']).to eq('UNAUTHENTICATED')
      end
    end

    context 'when user is not authenticated' do
      let(:context) { {} }

      it 'denies access' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session.id },
          context: context
        )

        expect(result['errors']).to be_present
        expect(result['errors'].first['message']).to eq('Access denied')
      end
    end
  end

  describe 'error handling' do
    let(:context) do
      {
        current_user: { session_id: session.id, role: 'parent' },
        current_session: session
      }
    end

    context 'when session does not exist' do
      it 'returns not found error' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: 'nonexistent-id' },
          context: context
        )

        expect(result['errors']).to be_present
        expect(result['errors'].first['message']).to eq('Session not found')
        expect(result['errors'].first['extensions']['code']).to eq('NOT_FOUND')
      end
    end
  end
end
