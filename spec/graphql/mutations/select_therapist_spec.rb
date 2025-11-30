# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::SelectTherapist, type: :graphql do
  describe '.resolve' do
    let(:parent) { create(:parent) }
    let(:child) { create(:child) }
    let(:insurance) { create(:insurance) }
    let(:assessment) { create(:assessment, status: "complete") }
    let(:session) do
      create(:onboarding_session,
             parent: parent,
             child: child,
             insurance: insurance,
             assessment: assessment)
    end

    let(:therapist) { create(:therapist) }

    let!(:therapist_match) do
      create(:therapist_match,
             onboarding_session: session,
             matched_therapists: [
               {
                 therapist_id: therapist.id,
                 score: 85,
                 reasoning: "Great match"
               }
             ],
             criteria_used: { child_age: 10 },
             processing_time_ms: 1500)
    end

    let(:mutation) do
      <<~GQL
        mutation($sessionId: ID!, $therapistId: ID!) {
          selectTherapist(input: {
            sessionId: $sessionId,
            therapistId: $therapistId
          }) {
            success
            errors
            therapistMatch {
              id
              selectedTherapistId
            }
          }
        }
      GQL
    end

    context 'when user is authenticated and owns the session' do
      let(:context) { { current_session: session } }
      let(:variables) do
        {
          sessionId: session.id,
          therapistId: therapist.id
        }
      end

      it 'records the therapist selection' do
        result = DaybreakHealthBackendSchema.execute(mutation, variables: variables, context: context)

        expect(result.dig('errors')).to be_nil
        expect(result.dig('data', 'selectTherapist', 'success')).to be true
        expect(result.dig('data', 'selectTherapist', 'errors')).to be_empty
      end

      it 'updates the therapist match record' do
        result = DaybreakHealthBackendSchema.execute(mutation, variables: variables, context: context)

        expect(result.dig('data', 'selectTherapist', 'therapistMatch', 'selectedTherapistId')).to eq(therapist.id)

        therapist_match.reload
        expect(therapist_match.selected_therapist_id).to eq(therapist.id)
      end
    end

    context 'when user is not authenticated' do
      let(:context) { { current_session: nil } }
      let(:variables) do
        {
          sessionId: session.id,
          therapistId: therapist.id
        }
      end

      it 'returns an authentication error' do
        result = DaybreakHealthBackendSchema.execute(mutation, variables: variables, context: context)

        expect(result.dig('errors')).to be_present
        expect(result.dig('errors', 0, 'extensions', 'code')).to eq('UNAUTHENTICATED')
      end
    end

    context 'when therapist does not exist' do
      let(:context) { { current_session: session } }
      let(:variables) do
        {
          sessionId: session.id,
          therapistId: SecureRandom.uuid
        }
      end

      it 'returns a not found error' do
        result = DaybreakHealthBackendSchema.execute(mutation, variables: variables, context: context)

        expect(result.dig('errors')).to be_present
        expect(result.dig('errors', 0, 'extensions', 'code')).to eq('NOT_FOUND')
      end
    end

    context 'when session has no matching results' do
      let(:new_session) do
        create(:onboarding_session,
               parent: parent,
               child: child,
               insurance: insurance,
               assessment: assessment)
      end
      let(:context) { { current_session: new_session } }
      let(:variables) do
        {
          sessionId: new_session.id,
          therapistId: therapist.id
        }
      end

      it 'returns an error' do
        result = DaybreakHealthBackendSchema.execute(mutation, variables: variables, context: context)

        expect(result.dig('data', 'selectTherapist', 'success')).to be false
        expect(result.dig('data', 'selectTherapist', 'errors')).to include("No matching results found for this session")
      end
    end
  end
end
