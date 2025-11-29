# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Session Query', type: :request do
  let(:session) { create(:onboarding_session) }
  let(:token) do
    Auth::JwtService.encode({
      session_id: session.id,
      role: 'anonymous'
    })
  end

  let(:query) do
    <<~GQL
      query GetSession($id: ID!) {
        session(id: $id) {
          id
          status
          progress
          createdAt
          updatedAt
          expiresAt
        }
      }
    GQL
  end

  describe 'POST /graphql' do
    context 'with valid token' do
      it 'returns the session' do
        post '/graphql',
          params: {
            query: query,
            variables: { id: session.id }
          },
          headers: { 'Authorization' => "Bearer #{token}" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_nil

        session_data = json.dig('data', 'session')
        # GraphQL returns ID with sess_ prefix
        expected_id = "sess_#{session.id.gsub('-', '')}"
        expect(session_data['id']).to eq(expected_id)
        expect(session_data['status']).to eq('started')
        expect(session_data['progress']).to eq({})
      end

      it 'works without Bearer prefix' do
        post '/graphql',
          params: {
            query: query,
            variables: { id: session.id }
          },
          headers: { 'Authorization' => token }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_nil
      end
    end

    context 'without token' do
      it 'returns UNAUTHENTICATED error' do
        post '/graphql',
          params: {
            query: query,
            variables: { id: session.id }
          }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors'].first['extensions']['code']).to eq('UNAUTHENTICATED')
      end
    end

    context 'with invalid token' do
      it 'returns UNAUTHENTICATED error' do
        post '/graphql',
          params: {
            query: query,
            variables: { id: session.id }
          },
          headers: { 'Authorization' => 'Bearer invalid.token.here' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors'].first['extensions']['code']).to eq('UNAUTHENTICATED')
      end
    end

    context 'with expired token' do
      let(:expired_token) do
        Auth::JwtService.encode(
          { session_id: session.id, role: 'anonymous' },
          exp: 1.hour.ago
        )
      end

      it 'returns UNAUTHENTICATED error' do
        post '/graphql',
          params: {
            query: query,
            variables: { id: session.id }
          },
          headers: { 'Authorization' => "Bearer #{expired_token}" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors'].first['extensions']['code']).to eq('UNAUTHENTICATED')
      end
    end

    context 'accessing different session' do
      let(:other_session) { create(:onboarding_session) }

      it 'returns UNAUTHENTICATED error' do
        post '/graphql',
          params: {
            query: query,
            variables: { id: other_session.id }
          },
          headers: { 'Authorization' => "Bearer #{token}" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors'].first['extensions']['code']).to eq('UNAUTHENTICATED')
      end
    end

    context 'session not found' do
      it 'returns NOT_FOUND error' do
        post '/graphql',
          params: {
            query: query,
            variables: { id: 'sess_nonexistent123' }
          },
          headers: { 'Authorization' => "Bearer #{token}" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors'].first['extensions']['code']).to eq('NOT_FOUND')
      end
    end
  end

  describe 'Full flow: create session then query it' do
    let(:create_mutation) do
      <<~GQL
        mutation {
          createSession(input: {}) {
            session {
              id
              status
            }
            token
          }
        }
      GQL
    end

    it 'creates session and queries it successfully' do
      # Create session
      post '/graphql',
        params: { query: create_mutation }.to_json,
        headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:ok)
      create_result = JSON.parse(response.body)
      expect(create_result['errors']).to be_nil

      new_session_id = create_result.dig('data', 'createSession', 'session', 'id')
      new_token = create_result.dig('data', 'createSession', 'token')

      # Query the created session
      post '/graphql',
        params: {
          query: query,
          variables: { id: new_session_id }
        }.to_json,
        headers: {
          'Authorization' => "Bearer #{new_token}",
          'Content-Type' => 'application/json'
        }

      expect(response).to have_http_status(:ok)
      query_result = JSON.parse(response.body)
      expect(query_result['errors']).to be_nil

      session_data = query_result.dig('data', 'session')
      expect(session_data['id']).to eq(new_session_id)
      expect(session_data['status']).to eq('started')
    end
  end
end
