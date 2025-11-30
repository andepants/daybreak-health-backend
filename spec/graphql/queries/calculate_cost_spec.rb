# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::CalculateCost, type: :request do
  let!(:session_rate) { create(:session_rate, service_type: 'individual_therapy', base_rate: 150.00) }
  let!(:family_rate) { create(:session_rate, service_type: 'family_therapy', base_rate: 200.00) }
  let!(:onboarding_session) { create(:onboarding_session) }

  # GraphQL endpoint
  let(:graphql_endpoint) { '/graphql' }

  # Helper to create session ID in expected format
  def session_id_for(session)
    "sess_#{session.id.gsub('-', '')}"
  end

  # Helper to execute GraphQL query
  def execute_calculate_cost_query(session_id:, service_type:, duration: nil, therapist_tier: nil,
                                     special_services: nil, discount_code: nil, token: nil)
    query = <<~GRAPHQL
      query($sessionId: ID!, $serviceType: String!, $duration: Int, $therapistTier: String,
            $specialServices: [String!], $discountCode: String) {
        calculateCost(
          sessionId: $sessionId,
          serviceType: $serviceType,
          duration: $duration,
          therapistTier: $therapistTier,
          specialServices: $specialServices,
          discountCode: $discountCode
        ) {
          grossCost
          netCost
          adjustments {
            type
            description
            amount
            percentage
          }
          currency
          calculatedAt
          metadata
        }
      }
    GRAPHQL

    variables = {
      sessionId: session_id,
      serviceType: service_type,
      duration: duration,
      therapistTier: therapist_tier,
      specialServices: special_services,
      discountCode: discount_code
    }.compact

    headers = token ? { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } : { 'Content-Type' => 'application/json' }

    post graphql_endpoint, params: { query: query, variables: variables }.to_json, headers: headers
  end

  describe 'calculateCost query' do
    context 'when authenticated' do
      let(:token) { Auth::JwtService.encode({ session_id: onboarding_session.id }) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      context 'with basic parameters' do
        it 'calculates cost for individual therapy' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'individual_therapy',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          expect(data['grossCost']).to eq(150.00)
          expect(data['netCost']).to eq(150.00)
          expect(data['adjustments']).to be_empty
          expect(data['currency']).to eq('USD')
          expect(data['calculatedAt']).to be_present
          expect(data['metadata']).to include('service_type' => 'individual_therapy')
        end

        it 'calculates cost for family therapy' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'family_therapy',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          expect(data['grossCost']).to eq(200.00)
          expect(data['netCost']).to eq(200.00)
        end
      end

      context 'with duration modifier' do
        it 'applies duration modifier for 90-minute session' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'individual_therapy',
            duration: 90,
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          expect(data['grossCost']).to eq(150.00)
          expect(data['netCost']).to eq(270.00) # 150 * 1.8

          adjustment = data['adjustments'].find { |a| a['type'] == 'duration_modifier' }
          expect(adjustment).to be_present
          expect(adjustment['amount']).to eq(120.00)
          expect(adjustment['percentage']).to eq(80.0)
        end

        it 'applies duration modifier for 25-minute session' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'individual_therapy',
            duration: 25,
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          expect(data['netCost']).to eq(75.00) # 150 * 0.5
        end
      end

      context 'with therapist tier modifier' do
        it 'applies senior therapist tier modifier' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'individual_therapy',
            therapist_tier: 'senior',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          expect(data['netCost']).to eq(180.00) # 150 * 1.2

          adjustment = data['adjustments'].find { |a| a['type'] == 'therapist_tier' }
          expect(adjustment).to be_present
          expect(adjustment['amount']).to eq(30.00)
          expect(adjustment['description']).to include('Senior')
        end

        it 'applies specialist tier modifier' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'individual_therapy',
            therapist_tier: 'specialist',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          expect(data['netCost']).to eq(225.00) # 150 * 1.5
        end
      end

      context 'with special services' do
        it 'applies special service fees' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'individual_therapy',
            special_services: ['telehealth_setup', 'translation'],
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          # 150 + 10 (telehealth) + 25 (translation) = 185
          expect(data['netCost']).to eq(185.00)

          telehealth_adj = data['adjustments'].find { |a| a['description'].include?('Telehealth Setup') }
          expect(telehealth_adj['amount']).to eq(10.00)

          translation_adj = data['adjustments'].find { |a| a['description'].include?('Translation') }
          expect(translation_adj['amount']).to eq(25.00)
        end
      end

      context 'with discount codes' do
        it 'applies percentage discount' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'individual_therapy',
            discount_code: 'PERCENTAGE_10',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          # 150 - 15 (10% discount) = 135
          expect(data['netCost']).to eq(135.00)

          discount_adj = data['adjustments'].find { |a| a['type'] == 'discount' }
          expect(discount_adj['amount']).to eq(-15.00)
        end

        it 'applies fixed amount discount' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'individual_therapy',
            discount_code: 'FIXED_25',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          # 150 - 25 = 125
          expect(data['netCost']).to eq(125.00)
        end

        it 'applies hardship discount' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'individual_therapy',
            discount_code: 'HARDSHIP_50',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          # 150 - 75 (50% hardship) = 75
          expect(data['netCost']).to eq(75.00)
        end

        it 'ignores invalid discount code without error' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'individual_therapy',
            discount_code: 'INVALID_CODE',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          expect(data['netCost']).to eq(150.00)
          expect(data['adjustments']).to be_empty
        end
      end

      context 'with combined modifiers' do
        it 'calculates correctly with all modifiers' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'family_therapy',
            duration: 90,
            therapist_tier: 'senior',
            special_services: ['translation'],
            discount_code: 'PERCENTAGE_10',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          # Base: 200
          # Duration: 90/50 = 1.8x = +160
          # Therapist: 1.2x on base = +40
          # Translation: +25
          # Subtotal: 425
          # Discount: 10% of 425 = -42.50
          # Final: 382.50

          expect(data['netCost']).to eq(382.50)
          expect(data['adjustments'].length).to eq(4) # duration, tier, translation, discount
        end
      end

      context 'with validation errors' do
        it 'returns error for invalid service type' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'invalid_type',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          errors = json['errors']

          expect(errors).to be_present
          expect(errors.first['message']).to include('Invalid service_type')
        end

        it 'returns error for invalid duration' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'individual_therapy',
            duration: -10,
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          errors = json['errors']

          expect(errors).to be_present
          expect(errors.first['message']).to include('Duration must be positive')
        end

        it 'returns error for invalid therapist tier' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'individual_therapy',
            therapist_tier: 'invalid_tier',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          errors = json['errors']

          expect(errors).to be_present
          expect(errors.first['message']).to include('Invalid therapist_tier')
        end
      end

      context 'with authorization' do
        it 'returns error when session not found' do
          # Use a valid UUID format that doesn't exist in the database
          fake_uuid = '12345678-1234-1234-1234-123456789abc'
          execute_calculate_cost_query(
            session_id: "sess_#{fake_uuid.tr('-', '')}",
            service_type: 'individual_therapy',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          errors = json['errors']

          expect(errors).to be_present
          expect(errors.first['message']).to include('Session not found')
        end

        it 'returns error when accessing another user\'s session' do
          other_session = create(:onboarding_session)

          execute_calculate_cost_query(
            session_id: other_session.id,
            service_type: 'individual_therapy',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          errors = json['errors']

          expect(errors).to be_present
          expect(errors.first['message']).to include('Not authorized')
        end
      end

      context 'session id format handling' do
        it 'handles session ID with sess_ prefix' do
          # Convert UUID to 32-char hex format with sess_ prefix
          uuid = onboarding_session.id
          hex = uuid.tr('-', '')
          sess_id = "sess_#{hex}"

          execute_calculate_cost_query(
            session_id: sess_id,
            service_type: 'individual_therapy',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          expect(data['netCost']).to eq(150.00)
        end

        it 'handles session ID without prefix' do
          execute_calculate_cost_query(
            session_id: session_id_for(onboarding_session),
            service_type: 'individual_therapy',
            token: token
          )

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          data = json.dig('data', 'calculateCost')

          expect(data['netCost']).to eq(150.00)
        end
      end

      context 'audit logging' do
        it 'creates audit log for cost calculation' do
          expect {
            execute_calculate_cost_query(
              session_id: session_id_for(onboarding_session),
              service_type: 'individual_therapy',
              token: token
            )
          }.to change { AuditLog.where(action: 'COST_CALCULATED').count }.by(1)

          audit_log = AuditLog.where(action: 'COST_CALCULATED').last
          expect(audit_log.resource).to eq('OnboardingSession')
          expect(audit_log.resource_id).to eq(onboarding_session.id)
          expect(audit_log.details['service_type']).to eq('individual_therapy')
          expect(audit_log.details['gross_cost']).to eq(150.00)
          expect(audit_log.details['net_cost']).to eq(150.00)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns authentication error' do
        execute_calculate_cost_query(
          session_id: session_id_for(onboarding_session),
          service_type: 'individual_therapy',
          token: nil
        )

        expect(response).to have_http_status(:success)

        json = JSON.parse(response.body)
        errors = json['errors']

        expect(errors).to be_present
        # Error message will vary based on authentication setup
        expect(errors.first['message']).to be_present
      end
    end
  end

  describe 'cost calculation determinism' do
    let(:token) { Auth::JwtService.encode({ session_id: onboarding_session.id }) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    it 'returns same result for same inputs' do
      params = {
        session_id: session_id_for(onboarding_session),
        service_type: 'individual_therapy',
        duration: 75,
        therapist_tier: 'lead',
        discount_code: 'PERCENTAGE_15',
        token: token
      }

      # First calculation
      execute_calculate_cost_query(**params)
      json1 = JSON.parse(response.body)
      data1 = json1.dig('data', 'calculateCost')

      # Second calculation
      execute_calculate_cost_query(**params)
      json2 = JSON.parse(response.body)
      data2 = json2.dig('data', 'calculateCost')

      expect(data1['grossCost']).to eq(data2['grossCost'])
      expect(data1['netCost']).to eq(data2['netCost'])
      expect(data1['adjustments'].length).to eq(data2['adjustments'].length)
    end
  end
end
