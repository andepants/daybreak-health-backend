# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Types::OnboardingSessionType, type: :graphql do
  describe 'fields' do
    subject(:type) { described_class }

    it 'has expected fields' do
      expect(type.fields.keys).to include(
        'id',
        'status',
        'progress',
        'referralSource',
        'createdAt',
        'updatedAt',
        'expiresAt'
      )
    end

    it 'has correct field types' do
      expect(type.fields['id'].type.to_type_signature).to eq('ID!')
      expect(type.fields['status'].type.to_type_signature).to eq('String!')
      expect(type.fields['progress'].type.to_type_signature).to eq('JSON!')
      expect(type.fields['referralSource'].type.to_type_signature).to eq('String')
      expect(type.fields['createdAt'].type.to_type_signature).to eq('ISO8601DateTime!')
      expect(type.fields['updatedAt'].type.to_type_signature).to eq('ISO8601DateTime!')
      expect(type.fields['expiresAt'].type.to_type_signature).to eq('ISO8601DateTime!')
    end
  end

  describe '#id transformation' do
    let(:session) { create(:onboarding_session) }
    let(:query) do
      <<~GQL
        query GetSession($id: ID!) {
          session(id: $id) {
            id
            status
          }
        }
      GQL
    end

    before do
      # Generate token for authentication
      @token = Auth::JwtService.encode(
        { session_id: session.id, role: 'anonymous' },
        exp: 1.hour.from_now
      )
    end

    it 'adds sess_ prefix to UUID in GraphQL response' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { id: session.id },
        context: { current_session: session }
      )

      session_id = result.dig('data', 'session', 'id')
      expect(session_id).to start_with('sess_')
    end

    it 'removes hyphens from UUID' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { id: session.id },
        context: { current_session: session }
      )

      session_id = result.dig('data', 'session', 'id')
      expect(session_id).not_to include('-')
    end

    it 'produces a valid CUID-like format (sess_ + 32 hex chars)' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { id: session.id },
        context: { current_session: session }
      )

      session_id = result.dig('data', 'session', 'id')
      expect(session_id).to match(/^sess_[a-f0-9]{32}$/)
    end

    it 'converts UUID correctly to CUID-like format' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { id: session.id },
        context: { current_session: session }
      )

      session_id = result.dig('data', 'session', 'id')
      expected_id = "sess_#{session.id.gsub('-', '')}"
      expect(session_id).to eq(expected_id)
    end

    context 'with specific UUID' do
      let(:session) { create(:onboarding_session, id: '123e4567-e89b-12d3-a456-426614174000') }

      it 'transforms UUID correctly' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { id: session.id },
          context: { current_session: session }
        )

        session_id = result.dig('data', 'session', 'id')
        expect(session_id).to eq('sess_123e4567e89b12d3a456426614174000')
      end
    end
  end

  describe 'field descriptions' do
    it 'id field mentions CUID format with sess_ prefix' do
      field = described_class.fields['id']
      expect(field.description).to include('CUID')
      expect(field.description).to include('sess_')
    end

    it 'status field has description' do
      field = described_class.fields['status']
      expect(field.description).to be_present
    end

    it 'progress field has description' do
      field = described_class.fields['progress']
      expect(field.description).to be_present
    end
  end
end
