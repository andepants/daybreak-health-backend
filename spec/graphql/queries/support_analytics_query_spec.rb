# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'supportAnalytics query', type: :graphql do
  let(:session1) { create(:onboarding_session, status: :in_progress) }
  let(:session2) { create(:onboarding_session, status: :submitted) }

  let!(:support_request1) do
    create(:support_request,
           onboarding_session: session1,
           source: 'insurance-verification',
           resolved: true)
  end

  let!(:support_request2) do
    create(:support_request,
           onboarding_session: session1,
           source: 'welcome-screen',
           resolved: false)
  end

  let!(:support_request3) do
    create(:support_request,
           onboarding_session: session2,
           source: 'insurance-verification',
           resolved: true)
  end

  let(:query) do
    <<~GQL
      query SupportAnalytics {
        supportAnalytics {
          totalRequests
          sessionsWithSupport
          resolutionRate
          requestsBySource
          requestsBySessionStatus
          averageResolutionTime
        }
      }
    GQL
  end

  describe 'successful query' do
    let(:context) do
      {
        current_user: { session_id: session1.id, role: 'admin' }
      }
    end

    it 'returns complete analytics data' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: {},
        context: context
      )

      data = result.dig('data', 'supportAnalytics')
      expect(data).to be_present
      expect(data['totalRequests']).to eq(3)
      expect(data['sessionsWithSupport']).to eq(2)
      expect(data['resolutionRate']).to be_within(0.1).of(66.67)
      expect(data['requestsBySource']).to be_a(Hash)
      expect(data['requestsBySessionStatus']).to be_a(Hash)
    end

    it 'groups requests by source correctly' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: {},
        context: context
      )

      by_source = result.dig('data', 'supportAnalytics', 'requestsBySource')
      expect(by_source['insurance-verification']).to eq(2)
      expect(by_source['welcome-screen']).to eq(1)
    end

    it 'provides requests by session status' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: {},
        context: context
      )

      by_status = result.dig('data', 'supportAnalytics', 'requestsBySessionStatus')
      # The result should be a hash (structure test - actual values depend on enum implementation)
      expect(by_status).to be_a(Hash)
    end
  end

  describe 'authorization' do
    context 'when user is an admin' do
      let(:context) do
        {
          current_user: { session_id: session1.id, role: 'admin' }
        }
      end

      it 'allows access' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: {},
          context: context
        )

        expect(result['errors']).to be_nil
        expect(result.dig('data', 'supportAnalytics')).to be_present
      end
    end

    context 'when user is not an admin' do
      let(:context) do
        {
          current_user: { session_id: session1.id, role: 'parent' }
        }
      end

      it 'denies access' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: {},
          context: context
        )

        expect(result['errors']).to be_present
        expect(result['errors'].first['message']).to eq('Access denied - admin only')
        expect(result['errors'].first['extensions']['code']).to eq('FORBIDDEN')
      end
    end

    context 'when user is not authenticated' do
      let(:context) { {} }

      it 'denies access' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: {},
          context: context
        )

        expect(result['errors']).to be_present
        expect(result['errors'].first['message']).to eq('Access denied - admin only')
      end
    end
  end

  describe 'with date filters' do
    let(:query_with_dates) do
      <<~GQL
        query SupportAnalytics($startDate: ISO8601Date, $endDate: ISO8601Date) {
          supportAnalytics(startDate: $startDate, endDate: $endDate) {
            totalRequests
            sessionsWithSupport
          }
        }
      GQL
    end

    let(:context) do
      {
        current_user: { session_id: session1.id, role: 'admin' }
      }
    end

    it 'filters analytics by date range' do
      # Create old support request
      old_request = create(:support_request,
                           onboarding_session: session1,
                           source: 'assessment')
      old_request.update_column(:created_at, 1.month.ago)

      # Query for a date range that should include all but the old request
      result = DaybreakHealthBackendSchema.execute(
        query_with_dates,
        variables: {
          startDate: 1.week.ago.to_date.iso8601,
          endDate: 1.day.from_now.to_date.iso8601
        },
        context: context
      )

      data = result.dig('data', 'supportAnalytics')
      # Should include 3 recent requests, exclude 1 old request
      expect(data['totalRequests']).to eq(3)
    end
  end
end
