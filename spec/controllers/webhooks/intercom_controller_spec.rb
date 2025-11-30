# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::IntercomController, type: :controller do
  let(:session) { create(:onboarding_session) }
  let(:webhook_secret) { 'test_webhook_secret' }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('INTERCOM_WEBHOOK_SECRET').and_return(webhook_secret)
  end

  describe 'POST #create' do
    let(:payload) do
      {
        type: 'notification_event',
        topic: 'conversation.user.created',
        data: {
          item: {
            id: '123456',
            user: {
              custom_attributes: {
                session_id: session.id,
                source: 'insurance-verification'
              }
            }
          }
        }
      }
    end

    let(:payload_json) { payload.to_json }

    def generate_signature(body, secret)
      "sha1=#{OpenSSL::HMAC.hexdigest('sha1', secret, body)}"
    end

    context 'with valid signature' do
      before do
        request.headers['X-Hub-Signature'] = generate_signature(payload_json, webhook_secret)
      end

      context 'conversation.user.created event' do
        it 'creates a support request' do
          expect do
            post :create, body: payload_json
          end.to change(SupportRequest, :count).by(1)

          expect(response).to have_http_status(:ok)
        end

        it 'flags the session as contacted_support' do
          post :create, body: payload_json

          expect(session.reload.contacted_support).to be true
        end

        it 'stores the conversation ID and source' do
          post :create, body: payload_json

          request = SupportRequest.last
          expect(request.intercom_conversation_id).to eq('123456')
          expect(request.source).to eq('insurance-verification')
          expect(request.resolved).to be false
        end

        context 'when session is not found' do
          let(:payload) do
            {
              type: 'notification_event',
              topic: 'conversation.user.created',
              data: {
                item: {
                  id: '123456',
                  user: {
                    custom_attributes: {
                      session_id: 'nonexistent-id',
                      source: 'insurance-verification'
                    }
                  }
                }
              }
            }
          end

          it 'does not create a support request' do
            expect do
              post :create, body: payload.to_json
            end.not_to change(SupportRequest, :count)

            expect(response).to have_http_status(:ok)
          end
        end

        context 'when source is missing' do
          let(:payload) do
            {
              type: 'notification_event',
              topic: 'conversation.user.created',
              data: {
                item: {
                  id: '123456',
                  user: {
                    custom_attributes: {
                      session_id: session.id
                    }
                  }
                }
              }
            }
          end

          it 'uses "unknown" as default source' do
            post :create, body: payload.to_json

            request = SupportRequest.last
            expect(request.source).to eq('unknown')
          end
        end
      end

      context 'conversation.user.replied event' do
        let!(:support_request) do
          create(:support_request,
                 onboarding_session: session,
                 intercom_conversation_id: '123456')
        end

        let(:payload) do
          {
            type: 'notification_event',
            topic: 'conversation.user.replied',
            data: {
              item: {
                id: '123456'
              }
            }
          }
        end

        it 'updates the support request timestamp' do
          original_time = support_request.updated_at
          travel 1.hour

          post :create, body: payload.to_json

          expect(support_request.reload.updated_at).to be > original_time
          expect(response).to have_http_status(:ok)
        end
      end

      context 'conversation.admin.closed event' do
        let!(:support_request) do
          create(:support_request,
                 onboarding_session: session,
                 intercom_conversation_id: '123456')
        end

        let(:payload) do
          {
            type: 'notification_event',
            topic: 'conversation.admin.closed',
            data: {
              item: {
                id: '123456'
              }
            }
          }
        end

        it 'marks the support request as resolved' do
          post :create, body: payload.to_json

          expect(support_request.reload.resolved).to be true
          expect(response).to have_http_status(:ok)
        end
      end

      context 'unknown topic' do
        let(:payload) do
          {
            type: 'notification_event',
            topic: 'conversation.unknown',
            data: {}
          }
        end

        it 'returns ok without processing' do
          post :create, body: payload.to_json

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with invalid signature' do
      before do
        request.headers['X-Hub-Signature'] = 'sha1=invalid_signature'
      end

      it 'returns unauthorized' do
        post :create, body: payload_json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not create a support request' do
        expect do
          post :create, body: payload_json
        end.not_to change(SupportRequest, :count)
      end
    end

    context 'with missing signature' do
      it 'returns unauthorized' do
        post :create, body: payload_json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when webhook secret is not configured' do
      before do
        allow(ENV).to receive(:[]).with('INTERCOM_WEBHOOK_SECRET').and_return(nil)
        request.headers['X-Hub-Signature'] = generate_signature(payload_json, webhook_secret)
      end

      it 'returns internal server error' do
        post :create, body: payload_json

        expect(response).to have_http_status(:internal_server_error)
      end
    end

    context 'error handling' do
      before do
        request.headers['X-Hub-Signature'] = generate_signature(payload_json, webhook_secret)
        allow(OnboardingSession).to receive(:find_by).and_raise(StandardError, 'Database error')
      end

      it 'returns ok to prevent retries' do
        post :create, body: payload_json

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
