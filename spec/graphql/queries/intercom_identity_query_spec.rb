# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'intercomIdentity query', type: :graphql do
  let(:session) { create(:onboarding_session, :with_parent, status: :in_progress) }
  let(:session_id_prefixed) { "sess_#{session.id.gsub('-', '')}" }
  let(:app_id) { 'test_app_123' }
  let(:secret_key) { 'a' * 32 } # 32-char secret key

  let(:query) do
    <<~GQL
      query IntercomIdentity($sessionId: ID!) {
        intercomIdentity(sessionId: $sessionId) {
          appId
          userHash
          userId
          enabled
        }
      }
    GQL
  end

  let(:context) do
    {
      current_session: session,
      ip_address: '192.168.1.1',
      user_agent: 'Mozilla/5.0'
    }
  end

  before do
    # Set Intercom environment variables
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('INTERCOM_APP_ID').and_return(app_id)
    allow(ENV).to receive(:[]).with('INTERCOM_SECRET_KEY').and_return(secret_key)
    allow(ENV).to receive(:[]).with('INTERCOM_ENABLED').and_return('true')
  end

  describe 'successful query' do
    it 'returns Intercom identity data for authenticated session' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      data = result.dig('data', 'intercomIdentity')
      expect(data).to be_present
      expect(data['appId']).to eq(app_id)
      expect(data['userId']).to eq(session.id)
      expect(data['enabled']).to be true
      expect(data['userHash']).to be_present
    end

    it 'returns valid HMAC-SHA256 hash' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      user_hash = result.dig('data', 'intercomIdentity', 'userHash')
      expected_hash = OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new('sha256'),
        secret_key,
        session.id
      )

      expect(user_hash).to eq(expected_hash)
    end

    it 'accepts UUID format session ID' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session.id },
        context: context
      )

      data = result.dig('data', 'intercomIdentity')
      expect(data).to be_present
      expect(data['userId']).to eq(session.id)
    end

    it 'accepts sess_ prefixed session ID' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      data = result.dig('data', 'intercomIdentity')
      expect(data).to be_present
      expect(data['userId']).to eq(session.id)
    end
  end

  describe 'authorization' do
    context 'when user is not authenticated' do
      let(:context) do
        {
          current_session: nil,
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        }
      end

      it 'returns UNAUTHENTICATED error' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        errors = result['errors']
        expect(errors).to be_present
        expect(errors.first['message']).to include('Access denied')
        expect(errors.first['extensions']['code']).to eq('UNAUTHENTICATED')
      end
    end

    context 'when user tries to access different session' do
      let(:other_session) { create(:onboarding_session, :with_parent) }
      let(:other_session_id) { "sess_#{other_session.id.gsub('-', '')}" }

      it 'returns UNAUTHENTICATED error' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: other_session_id },
          context: context
        )

        errors = result['errors']
        expect(errors).to be_present
        expect(errors.first['message']).to include('Access denied')
        expect(errors.first['extensions']['code']).to eq('UNAUTHENTICATED')
      end
    end
  end

  describe 'error handling' do
    context 'when session does not exist' do
      let(:non_existent_id) { 'sess_' + ('0' * 32) }

      it 'returns NOT_FOUND error' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: non_existent_id },
          context: context
        )

        errors = result['errors']
        expect(errors).to be_present
        expect(errors.first['message']).to include('Session not found')
        expect(errors.first['extensions']['code']).to eq('NOT_FOUND')
      end
    end
  end

  describe 'Intercom disabled' do
    before do
      allow(ENV).to receive(:[]).with('INTERCOM_APP_ID').and_return(nil)
      allow(ENV).to receive(:[]).with('INTERCOM_SECRET_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('INTERCOM_ENABLED').and_return(nil)
    end

    it 'returns enabled: false when Intercom is not configured' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      data = result.dig('data', 'intercomIdentity')
      expect(data['enabled']).to be false
      expect(data['userHash']).to be_nil
    end
  end

  describe 'HIPAA compliance' do
    it 'only returns session ID as user identifier (no PHI)' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      data = result.dig('data', 'intercomIdentity')

      # Verify only non-PHI data is returned
      expect(data.keys).to match_array(%w[appId userHash userId enabled])
      expect(data['userId']).to eq(session.id) # Only session ID

      # Verify no PHI fields are present
      expect(data.keys).not_to include('name', 'email', 'phone', 'dob')
    end

    it 'uses secure HMAC-SHA256 hash for identity verification' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      user_hash = result.dig('data', 'intercomIdentity', 'userHash')

      # Verify hash is valid SHA256 hex string (64 characters)
      expect(user_hash).to match(/\A[a-f0-9]{64}\z/)
    end
  end

  describe 'integration with IntercomService' do
    it 'delegates to Support::IntercomService' do
      service_double = instance_double(Support::IntercomService)
      expected_result = {
        app_id: app_id,
        user_hash: 'test_hash',
        user_id: session.id,
        enabled: true
      }

      allow(Support::IntercomService).to receive(:call).with(session_id: session.id)
                                                        .and_return(expected_result)

      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      data = result.dig('data', 'intercomIdentity')
      expect(data['appId']).to eq(app_id)
      expect(data['userHash']).to eq('test_hash')
      expect(data['userId']).to eq(session.id)
      expect(data['enabled']).to be true

      expect(Support::IntercomService).to have_received(:call).with(session_id: session.id)
    end
  end
end
