# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'financialAssistanceInfo query', type: :graphql do
  let(:query) do
    <<~GRAPHQL
      query FinancialAssistanceInfo {
        financialAssistanceInfo {
          available
          eligibilityCriteria
          applicationUrl
          description
          slidingScaleAvailable
          discountRange
          additionalInfo
        }
      }
    GRAPHQL
  end

  def execute_query
    DaybreakHealthBackendSchema.execute(
      query,
      variables: {},
      context: {
        ip_address: '127.0.0.1',
        user_agent: 'RSpec Test'
      }
    )
  end

  context 'when financial assistance is configured' do
    before do
      # Mock the configuration
      allow(Rails.application.config).to receive(:financial_assistance).and_return(
        available: true,
        eligibility_criteria: [
          'Annual household income below threshold for family size',
          'Active participation in therapy sessions',
          'No outstanding payment obligations',
          'Completion of financial assistance application'
        ],
        application_url: 'https://example.com/financial-assistance/apply',
        program_description: 'Daybreak Health is committed to making mental healthcare accessible to all families.',
        sliding_scale_discounts: {
          '0-100' => 75,
          '100-150' => 50,
          '150-200' => 35,
          '200-250' => 20
        },
        additional_info: [
          'Applications reviewed within 5 business days',
          'Confidential review process',
          'Assistance renewable annually',
          'No impact on quality of care'
        ]
      )
    end

    let(:result) { execute_query }
    let(:financial_assistance) { result.dig('data', 'financialAssistanceInfo') }

    it 'returns successful response' do
      expect(result['errors']).to be_nil
    end

    it 'returns financial assistance information' do
      expect(financial_assistance).to be_present
      expect(financial_assistance['available']).to be true
    end

    it 'includes eligibility criteria' do
      expect(financial_assistance['eligibilityCriteria']).to be_an(Array)
      expect(financial_assistance['eligibilityCriteria'].length).to eq(4)
      expect(financial_assistance['eligibilityCriteria']).to include(
        'Annual household income below threshold for family size',
        'Active participation in therapy sessions',
        'No outstanding payment obligations',
        'Completion of financial assistance application'
      )
    end

    it 'includes application URL' do
      expect(financial_assistance['applicationUrl']).to eq('https://example.com/financial-assistance/apply')
    end

    it 'includes program description' do
      expect(financial_assistance['description']).to include('Daybreak Health')
      expect(financial_assistance['description']).to include('accessible to all families')
    end

    it 'indicates sliding scale is available' do
      expect(financial_assistance['slidingScaleAvailable']).to be true
    end

    it 'includes discount range' do
      expect(financial_assistance['discountRange']).to eq('20-75%')
    end

    it 'includes additional information' do
      expect(financial_assistance['additionalInfo']).to be_an(Array)
      expect(financial_assistance['additionalInfo'].length).to eq(4)
      expect(financial_assistance['additionalInfo']).to include(
        'Applications reviewed within 5 business days',
        'Confidential review process',
        'Assistance renewable annually',
        'No impact on quality of care'
      )
    end
  end

  context 'when sliding scale discounts are not configured' do
    before do
      allow(Rails.application.config).to receive(:financial_assistance).and_return(
        available: true,
        eligibility_criteria: ['Some criteria'],
        application_url: 'https://example.com/apply',
        program_description: 'Program description',
        sliding_scale_discounts: nil,
        additional_info: []
      )
    end

    let(:result) { execute_query }
    let(:financial_assistance) { result.dig('data', 'financialAssistanceInfo') }

    it 'indicates sliding scale is not available' do
      expect(financial_assistance['slidingScaleAvailable']).to be false
    end

    it 'returns "Not available" for discount range' do
      expect(financial_assistance['discountRange']).to eq('Not available')
    end
  end

  context 'when financial assistance is not available' do
    before do
      allow(Rails.application.config).to receive(:financial_assistance).and_return(
        available: false,
        eligibility_criteria: [],
        application_url: '',
        program_description: 'Financial assistance not currently available',
        sliding_scale_discounts: {},
        additional_info: []
      )
    end

    let(:result) { execute_query }
    let(:financial_assistance) { result.dig('data', 'financialAssistanceInfo') }

    it 'indicates program is not available' do
      expect(financial_assistance['available']).to be false
    end

    it 'returns empty eligibility criteria' do
      expect(financial_assistance['eligibilityCriteria']).to eq([])
    end
  end

  context 'when configuration is missing' do
    before do
      allow(Rails.application.config).to receive(:financial_assistance).and_return(nil)
    end

    let(:result) { execute_query }
    let(:financial_assistance) { result.dig('data', 'financialAssistanceInfo') }

    it 'returns default values' do
      expect(financial_assistance['available']).to be false
      expect(financial_assistance['eligibilityCriteria']).to eq([])
      expect(financial_assistance['applicationUrl']).to eq('')
      expect(financial_assistance['description']).to include('not available')
    end
  end

  context 'field accessibility' do
    before do
      allow(Rails.application.config).to receive(:financial_assistance).and_return(
        available: true,
        eligibility_criteria: ['Test criteria'],
        application_url: 'https://example.com/apply',
        program_description: 'Test description',
        sliding_scale_discounts: { '0-100' => 50 },
        additional_info: ['Test info']
      )
    end

    it 'is accessible without authentication' do
      # Query without any session context
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: {},
        context: {}
      )

      expect(result['errors']).to be_nil
      financial_assistance = result.dig('data', 'financialAssistanceInfo')
      expect(financial_assistance).to be_present
    end

    it 'provides consistent information across requests' do
      result1 = execute_query
      result2 = execute_query

      assistance1 = result1.dig('data', 'financialAssistanceInfo')
      assistance2 = result2.dig('data', 'financialAssistanceInfo')

      expect(assistance1).to eq(assistance2)
    end
  end

  context 'integration with payment plan options' do
    let(:full_query) do
      <<~GRAPHQL
        query FinancialContext {
          financialAssistanceInfo {
            available
            applicationUrl
            discountRange
          }
        }
      GRAPHQL
    end

    before do
      allow(Rails.application.config).to receive(:financial_assistance).and_return(
        available: true,
        eligibility_criteria: ['Test'],
        application_url: 'https://example.com/apply',
        program_description: 'Test',
        sliding_scale_discounts: { '0-100' => 75, '100-200' => 50 },
        additional_info: []
      )
    end

    it 'provides information that complements payment plan options' do
      result = DaybreakHealthBackendSchema.execute(
        full_query,
        variables: {},
        context: {}
      )

      assistance = result.dig('data', 'financialAssistanceInfo')
      expect(assistance['available']).to be true
      expect(assistance['applicationUrl']).to be_present
      expect(assistance['discountRange']).to eq('50-75%')
    end
  end
end
