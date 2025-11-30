# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Types::CostEstimateType do
  it 'has the expected fields' do
    expected_fields = %w[
      insurancePays patientPays allowedAmount billedAmount
      deductibleStatus coverageLimitations isEstimate
      disclaimer calculatedAt
    ]
    expect(described_class.fields.keys).to include(*expected_fields)
  end

  it 'has proper field descriptions' do
    insurance_pays = described_class.fields['insurancePays']
    expect(insurance_pays.description).to include('insurance will pay')

    patient_pays = described_class.fields['patientPays']
    expect(patient_pays.description).to include('patient out-of-pocket')

    allowed_amount = described_class.fields['allowedAmount']
    expect(allowed_amount.description).to include('Allowed amount')

    disclaimer = described_class.fields['disclaimer']
    expect(disclaimer.description).to include('estimate only')
  end
end
