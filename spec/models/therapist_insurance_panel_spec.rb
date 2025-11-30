# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TherapistInsurancePanel, type: :model do
  describe 'associations' do
    it { should belong_to(:therapist) }
  end

  describe 'validations' do
    it { should validate_presence_of(:insurance_name) }
  end

  describe 'enums' do
    it do
      should define_enum_for(:network_status)
        .with_values(
          in_network: 0,
          out_of_network: 1
        )
    end

    it 'defaults to in_network' do
      panel = create(:therapist_insurance_panel)
      expect(panel.network_status).to eq('in_network')
    end

    it 'can be set to out_of_network' do
      panel = create(:therapist_insurance_panel, :out_of_network)
      expect(panel.network_status).to eq('out_of_network')
    end
  end

  describe 'creating insurance panels' do
    let(:therapist) { create(:therapist) }

    it 'can create multiple insurance panels for a therapist' do
      insurances = [
        { name: 'Aetna', state: 'CA', line: 'Commercial' },
        { name: 'Cigna', state: 'CA', line: 'Medicaid' },
        { name: 'UnitedHealthcare', state: 'TX', line: 'Commercial' }
      ]

      insurances.each do |ins|
        create(:therapist_insurance_panel,
               therapist: therapist,
               insurance_name: ins[:name],
               insurance_state: ins[:state],
               line_of_business: ins[:line])
      end

      expect(therapist.therapist_insurance_panels.count).to eq(3)
    end

    it 'can have same insurance in different states' do
      create(:therapist_insurance_panel,
             therapist: therapist,
             insurance_name: 'Molina',
             insurance_state: 'CA')

      create(:therapist_insurance_panel,
             therapist: therapist,
             insurance_name: 'Molina',
             insurance_state: 'UT')

      panels = therapist.therapist_insurance_panels.where(insurance_name: 'Molina')
      expect(panels.count).to eq(2)
      expect(panels.pluck(:insurance_state)).to contain_exactly('CA', 'UT')
    end
  end

  describe 'dependent destroy' do
    it 'is destroyed when therapist is destroyed' do
      therapist = create(:therapist, :with_insurance_panels)
      panel_ids = therapist.therapist_insurance_panels.pluck(:id)

      therapist.destroy

      panel_ids.each do |id|
        expect(TherapistInsurancePanel.find_by(id: id)).to be_nil
      end
    end
  end

  describe 'external_insurance_id tracking' do
    it 'stores external insurance ID for reference' do
      external_id = SecureRandom.uuid
      panel = create(:therapist_insurance_panel, external_insurance_id: external_id)

      expect(panel.reload.external_insurance_id).to eq(external_id)
    end
  end
end
