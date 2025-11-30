# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Types::DeductibleStatusType do
  it 'has the expected fields' do
    expect(described_class.fields.keys).to include('amount', 'met', 'remaining', 'isMet')
  end

  it 'amount field is non-null Float' do
    field = described_class.fields['amount']
    expect(field.type.to_type_signature).to eq('Float!')
  end

  it 'met field is non-null Float' do
    field = described_class.fields['met']
    expect(field.type.to_type_signature).to eq('Float!')
  end

  it 'remaining field is non-null Float' do
    field = described_class.fields['remaining']
    expect(field.type.to_type_signature).to eq('Float!')
  end

  it 'isMet field is non-null Boolean' do
    field = described_class.fields['isMet']
    expect(field.type.to_type_signature).to eq('Boolean!')
  end

  it 'has proper field descriptions' do
    amount_field = described_class.fields['amount']
    expect(amount_field.description).to include('Total annual deductible')

    met_field = described_class.fields['met']
    expect(met_field.description).to include('met so far')

    remaining_field = described_class.fields['remaining']
    expect(remaining_field.description).to include('remaining')

    is_met_field = described_class.fields['isMet']
    expect(is_met_field.description).to include('fully met')
  end
end
