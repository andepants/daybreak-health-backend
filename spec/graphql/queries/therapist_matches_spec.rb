# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::TherapistMatches, type: :graphql do
  describe '.resolve' do
    let(:parent) { create(:parent) }
    let(:child) { create(:child, date_of_birth: 10.years.ago) }
    let(:insurance) { create(:insurance, payer_name: "Aetna") }
    let(:assessment) { create(:assessment, status: "complete") }
    let(:session) do
      create(:onboarding_session,
             parent: parent,
             child: child,
             insurance: insurance,
             assessment: assessment)
    end

    let!(:therapist1) do
      create(:therapist,
             first_name: "Sarah",
             last_name: "Johnson",
             license_type: "LCSW",
             bio: "Specializing in child anxiety",
             age_ranges: ["5-12", "13-17"],
             active: true,
             license_state: "CA")
    end

    let!(:therapist2) do
      create(:therapist,
             first_name: "Michael",
             last_name: "Chen",
             license_type: "LMFT",
             bio: "Expert in adolescent therapy",
             age_ranges: ["13-17", "18-25"],
             active: true,
             license_state: "CA")
    end

    before do
      # Create specializations
      create(:therapist_specialization, therapist: therapist1, specialization: "anxiety")
      create(:therapist_specialization, therapist: therapist1, specialization: "depression")
      create(:therapist_specialization, therapist: therapist2, specialization: "adhd")
      create(:therapist_specialization, therapist: therapist2, specialization: "behavioral issues")

      # Create insurance panels
      create(:therapist_insurance_panel, therapist: therapist1, insurance_name: "Aetna")
      create(:therapist_insurance_panel, therapist: therapist2, insurance_name: "Aetna")

      # Add primary concerns to child
      child.update!(primary_concerns: "anxiety and nervousness")
    end

    let(:query) do
      <<~GQL
        query($sessionId: ID!) {
          therapistMatches(sessionId: $sessionId) {
            therapist {
              id
              fullName
              licenseType
              bio
            }
            score
            scoreBreakdown {
              specializationScore
              ageRangeScore
              availabilityScore
              modalityScore
            }
            reasoning
          }
        }
      GQL
    end

    context 'when user is authenticated and owns the session' do
      let(:context) { { current_session: session } }
      let(:variables) { { sessionId: session.id } }

      it 'returns matched therapists' do
        result = DaybreakHealthBackendSchema.execute(query, variables: variables, context: context)

        expect(result.dig('errors')).to be_nil
        expect(result.dig('data', 'therapistMatches')).to be_an(Array)
        expect(result.dig('data', 'therapistMatches').length).to be >= 1
      end

      it 'includes therapist profile information' do
        result = DaybreakHealthBackendSchema.execute(query, variables: variables, context: context)
        match = result.dig('data', 'therapistMatches', 0)

        expect(match['therapist']).to be_present
        expect(match['therapist']['fullName']).to be_present
        expect(match['therapist']['licenseType']).to be_present
        expect(match['therapist']['bio']).to be_present
      end

      it 'includes match score and breakdown' do
        result = DaybreakHealthBackendSchema.execute(query, variables: variables, context: context)
        match = result.dig('data', 'therapistMatches', 0)

        expect(match['score']).to be_a(Integer)
        expect(match['score']).to be_between(0, 100)
        expect(match['scoreBreakdown']).to be_present
        expect(match['scoreBreakdown']['specializationScore']).to be_a(Integer)
        expect(match['scoreBreakdown']['ageRangeScore']).to be_a(Integer)
      end

      it 'includes match reasoning' do
        result = DaybreakHealthBackendSchema.execute(query, variables: variables, context: context)
        match = result.dig('data', 'therapistMatches', 0)

        expect(match['reasoning']).to be_a(String)
        expect(match['reasoning'].length).to be > 0
      end
    end

    context 'when user is not authenticated' do
      let(:context) { { current_session: nil } }
      let(:variables) { { sessionId: session.id } }

      it 'returns an authentication error' do
        result = DaybreakHealthBackendSchema.execute(query, variables: variables, context: context)

        expect(result.dig('errors')).to be_present
        expect(result.dig('errors', 0, 'extensions', 'code')).to eq('UNAUTHENTICATED')
      end
    end

    context 'when user does not own the session' do
      let(:other_session) { create(:onboarding_session) }
      let(:context) { { current_session: other_session } }
      let(:variables) { { sessionId: session.id } }

      it 'returns an authentication error' do
        result = DaybreakHealthBackendSchema.execute(query, variables: variables, context: context)

        expect(result.dig('errors')).to be_present
        expect(result.dig('errors', 0, 'extensions', 'code')).to eq('UNAUTHENTICATED')
      end
    end

    context 'when session does not have complete assessment' do
      let(:incomplete_assessment) { create(:assessment, status: "in_progress") }
      let(:incomplete_session) do
        create(:onboarding_session,
               parent: parent,
               child: child,
               insurance: insurance,
               assessment: incomplete_assessment)
      end
      let(:context) { { current_session: incomplete_session } }
      let(:variables) { { sessionId: incomplete_session.id } }

      it 'returns a validation error' do
        result = DaybreakHealthBackendSchema.execute(query, variables: variables, context: context)

        expect(result.dig('errors')).to be_present
        expect(result.dig('errors', 0, 'extensions', 'code')).to eq('VALIDATION_ERROR')
        expect(result.dig('errors', 0, 'message')).to include('Assessment must be complete')
      end
    end

    context 'when session is not found' do
      let(:context) { { current_session: session } }
      let(:variables) { { sessionId: SecureRandom.uuid } }

      it 'returns a not found error' do
        result = DaybreakHealthBackendSchema.execute(query, variables: variables, context: context)

        expect(result.dig('errors')).to be_present
        expect(result.dig('errors', 0, 'extensions', 'code')).to eq('NOT_FOUND')
      end
    end
  end
end
