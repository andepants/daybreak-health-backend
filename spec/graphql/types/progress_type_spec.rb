# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Types::ProgressType do
  it 'has the expected fields' do
    expected_fields = %w[
      percentage
      currentPhase
      completedPhases
      nextPhase
      estimatedMinutesRemaining
    ]

    expect(described_class.fields.keys).to match_array(expected_fields)
  end

  describe 'field types and nullability' do
    it 'has percentage as non-null Integer' do
      field = described_class.fields['percentage']
      expect(field.type.to_type_signature).to eq('Int!')
    end

    it 'has currentPhase as non-null String' do
      field = described_class.fields['currentPhase']
      expect(field.type.to_type_signature).to eq('String!')
    end

    it 'has completedPhases as non-null array of String' do
      field = described_class.fields['completedPhases']
      expect(field.type.to_type_signature).to eq('[String!]!')
    end

    it 'has nextPhase as nullable String' do
      field = described_class.fields['nextPhase']
      expect(field.type.to_type_signature).to eq('String')
    end

    it 'has estimatedMinutesRemaining as non-null Integer' do
      field = described_class.fields['estimatedMinutesRemaining']
      expect(field.type.to_type_signature).to eq('Int!')
    end
  end

  describe 'field descriptions' do
    it 'has description for percentage' do
      field = described_class.fields['percentage']
      expect(field.description).to include('Progress percentage')
    end

    it 'has description for currentPhase' do
      field = described_class.fields['currentPhase']
      expect(field.description).to include('Current phase')
    end

    it 'has description for completedPhases' do
      field = described_class.fields['completedPhases']
      expect(field.description).to include('completed phase')
    end

    it 'has description for nextPhase' do
      field = described_class.fields['nextPhase']
      expect(field.description).to include('Next phase')
    end

    it 'has description for estimatedMinutesRemaining' do
      field = described_class.fields['estimatedMinutesRemaining']
      expect(field.description).to include('minutes')
    end
  end
end
