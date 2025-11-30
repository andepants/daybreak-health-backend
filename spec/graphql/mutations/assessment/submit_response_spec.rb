# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Assessment::SubmitResponse, type: :request do
  let(:session) { create(:onboarding_session) }
  let(:parent) { create(:parent, onboarding_session: session) }
  let(:child) { create(:child, onboarding_session: session, date_of_birth: 14.years.ago.to_s) }
  let(:insurance) { create(:insurance, onboarding_session: session, verification_status: :verified) }

  let(:mutation) do
    <<~GQL
      mutation SubmitAssessmentResponse($sessionId: ID!, $questionId: String!, $responseText: String!, $responseValue: Int) {
        submitAssessmentResponse(sessionId: $sessionId, questionId: $questionId, responseText: $responseText, responseValue: $responseValue) {
          assessment {
            id
            status
            progressPercentage
            completedQuestionsCount
            phqAComplete
            gad7Complete
          }
          nextQuestion {
            id
            text
            domain
            instrument
          }
          progress {
            status
            completedQuestions
            totalQuestions
            percentage
            phqAComplete
            gad7Complete
          }
          errors
        }
      }
    GQL
  end

  def session_id_for(session)
    "sess_#{session.id.gsub('-', '')}"
  end

  before do
    parent
    child
    insurance
  end

  describe 'authentication' do
    it 'requires authentication' do
      post '/graphql', params: {
        query: mutation,
        variables: {
          sessionId: session_id_for(session),
          questionId: 'phq_a_1',
          responseText: 'several days'
        }
      }

      json = JSON.parse(response.body)
      expect(json['data']['submitAssessmentResponse']['errors']).to include('Authentication required')
    end
  end

  context 'when authenticated' do
    let(:token) { Auth::JwtService.encode(session_id: session.id) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    describe 'submitting first response' do
      it 'creates assessment and records response' do
        post '/graphql', params: {
          query: mutation,
          variables: {
            sessionId: session_id_for(session),
            questionId: 'phq_a_1',
            responseText: 'several days'
          }
        }, headers: headers

        json = JSON.parse(response.body)
        result = json['data']['submitAssessmentResponse']

        expect(result['errors']).to be_empty
        expect(result['assessment']).to be_present
        expect(result['assessment']['status']).to eq('in_progress')
        expect(result['assessment']['completedQuestionsCount']).to eq(1)
        expect(result['progress']['percentage']).to eq(6) # 1/16
      end

      it 'returns next question' do
        post '/graphql', params: {
          query: mutation,
          variables: {
            sessionId: session_id_for(session),
            questionId: 'phq_a_1',
            responseText: 'not at all'
          }
        }, headers: headers

        json = JSON.parse(response.body)
        result = json['data']['submitAssessmentResponse']

        expect(result['nextQuestion']['id']).to eq('phq_a_2')
        expect(result['nextQuestion']['instrument']).to eq('PHQ-A')
      end
    end

    describe 'response parsing' do
      it 'parses "not at all" as 0' do
        post '/graphql', params: {
          query: mutation,
          variables: {
            sessionId: session_id_for(session),
            questionId: 'phq_a_1',
            responseText: 'not at all really'
          }
        }, headers: headers

        assessment = session.reload.assessment
        expect(assessment.phq_a_responses.first[:value]).to eq(0)
      end

      it 'parses "nearly every day" as 3' do
        post '/graphql', params: {
          query: mutation,
          variables: {
            sessionId: session_id_for(session),
            questionId: 'phq_a_1',
            responseText: 'nearly every day, honestly'
          }
        }, headers: headers

        assessment = session.reload.assessment
        expect(assessment.phq_a_responses.first[:value]).to eq(3)
      end

      it 'accepts explicit responseValue' do
        post '/graphql', params: {
          query: mutation,
          variables: {
            sessionId: session_id_for(session),
            questionId: 'phq_a_1',
            responseText: 'some custom response',
            responseValue: 2
          }
        }, headers: headers

        assessment = session.reload.assessment
        expect(assessment.phq_a_responses.first[:value]).to eq(2)
      end
    end

    describe 'FR26 validation' do
      it 'rejects response value > 3' do
        post '/graphql', params: {
          query: mutation,
          variables: {
            sessionId: session_id_for(session),
            questionId: 'phq_a_1',
            responseText: 'always',
            responseValue: 4
          }
        }, headers: headers

        json = JSON.parse(response.body)
        result = json['data']['submitAssessmentResponse']
        expect(result['errors']).to include('Response value must be between 0 and 3')
      end

      it 'rejects response value < 0' do
        post '/graphql', params: {
          query: mutation,
          variables: {
            sessionId: session_id_for(session),
            questionId: 'phq_a_1',
            responseText: 'never',
            responseValue: -1
          }
        }, headers: headers

        json = JSON.parse(response.body)
        result = json['data']['submitAssessmentResponse']
        expect(result['errors']).not_to be_empty
      end

      it 'rejects response text over 500 characters' do
        long_text = 'a' * 501
        post '/graphql', params: {
          query: mutation,
          variables: {
            sessionId: session_id_for(session),
            questionId: 'phq_a_1',
            responseText: long_text
          }
        }, headers: headers

        json = JSON.parse(response.body)
        result = json['data']['submitAssessmentResponse']
        expect(result['errors'].first).to include('500 characters')
      end

      it 'rejects invalid question ID' do
        post '/graphql', params: {
          query: mutation,
          variables: {
            sessionId: session_id_for(session),
            questionId: 'phq_a_99',
            responseText: 'several days'
          }
        }, headers: headers

        json = JSON.parse(response.body)
        result = json['data']['submitAssessmentResponse']
        expect(result['errors']).to include('Invalid question ID: phq_a_99')
      end
    end

    describe 'insurance phase prerequisite' do
      it 'requires insurance verification complete' do
        insurance.update!(verification_status: :pending)

        post '/graphql', params: {
          query: mutation,
          variables: {
            sessionId: session_id_for(session),
            questionId: 'phq_a_1',
            responseText: 'several days'
          }
        }, headers: headers

        json = JSON.parse(response.body)
        result = json['data']['submitAssessmentResponse']
        expect(result['errors']).to include('Insurance verification must be complete before assessment')
      end
    end

    describe 'phase transitions' do
      it 'transitions from PHQ-A to GAD-7 after 9 PHQ-A responses' do
        # Submit 9 PHQ-A responses
        (1..9).each do |i|
          post '/graphql', params: {
            query: mutation,
            variables: {
              sessionId: session_id_for(session),
              questionId: "phq_a_#{i}",
              responseText: 'several days'
            }
          }, headers: headers
        end

        json = JSON.parse(response.body)
        result = json['data']['submitAssessmentResponse']

        expect(result['progress']['phqAComplete']).to be true
        expect(result['nextQuestion']['id']).to eq('gad_7_1')
        expect(result['nextQuestion']['instrument']).to eq('GAD-7')
      end
    end

    describe 'duplicate prevention' do
      before do
        post '/graphql', params: {
          query: mutation,
          variables: {
            sessionId: session_id_for(session),
            questionId: 'phq_a_1',
            responseText: 'several days'
          }
        }, headers: headers
      end

      it 'rejects duplicate response for same question' do
        post '/graphql', params: {
          query: mutation,
          variables: {
            sessionId: session_id_for(session),
            questionId: 'phq_a_1',
            responseText: 'not at all'
          }
        }, headers: headers

        json = JSON.parse(response.body)
        result = json['data']['submitAssessmentResponse']
        expect(result['errors']).to include('Question already answered')
      end
    end

    describe 'session authorization' do
      it 'rejects access to other sessions' do
        other_session = create(:onboarding_session)

        post '/graphql', params: {
          query: mutation,
          variables: {
            sessionId: session_id_for(other_session),
            questionId: 'phq_a_1',
            responseText: 'several days'
          }
        }, headers: headers

        json = JSON.parse(response.body)
        result = json['data']['submitAssessmentResponse']
        expect(result['errors']).to include('Unauthorized access to session')
      end
    end
  end
end
