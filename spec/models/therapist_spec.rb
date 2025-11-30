# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Therapist, type: :model do
  describe 'associations' do
    it { should have_many(:therapist_specializations).dependent(:destroy) }
    it { should have_many(:therapist_insurance_panels).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }

    describe 'license_number uniqueness' do
      it 'validates uniqueness when present' do
        create(:therapist, license_number: 'LCSW123456')
        therapist = build(:therapist, license_number: 'LCSW123456')
        expect(therapist).not_to be_valid
        expect(therapist.errors[:license_number]).to include('has already been taken')
      end

      it 'allows nil license_number' do
        create(:therapist, license_number: nil)
        therapist = build(:therapist, license_number: nil)
        expect(therapist).to be_valid
      end
    end

    describe 'npi_number uniqueness' do
      it 'validates uniqueness when present' do
        create(:therapist, npi_number: '1234567890')
        therapist = build(:therapist, npi_number: '1234567890')
        expect(therapist).not_to be_valid
        expect(therapist.errors[:npi_number]).to include('has already been taken')
      end

      it 'allows nil npi_number' do
        create(:therapist, npi_number: nil)
        therapist = build(:therapist, npi_number: nil)
        expect(therapist).to be_valid
      end
    end

    describe 'email format' do
      it 'validates email format when present' do
        therapist = build(:therapist, email: 'invalid-email')
        expect(therapist).not_to be_valid
        expect(therapist.errors[:email]).to be_present
      end

      it 'allows valid email format' do
        therapist = build(:therapist, email: 'therapist@example.com')
        expect(therapist).to be_valid
      end

      it 'allows nil email' do
        therapist = build(:therapist, email: nil)
        expect(therapist).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:active_therapist) { create(:therapist, active: true) }
    let!(:inactive_therapist) { create(:therapist, :inactive) }
    let!(:ca_therapist) { create(:therapist, :california) }
    let!(:tx_therapist) { create(:therapist, :texas) }
    let!(:therapist_with_anxiety) do
      create(:therapist).tap do |t|
        create(:therapist_specialization, therapist: t, specialization: 'anxiety')
      end
    end

    describe '.active' do
      it 'returns only active therapists' do
        expect(Therapist.active).to include(active_therapist)
        expect(Therapist.active).not_to include(inactive_therapist)
      end
    end

    describe '.by_state' do
      it 'returns therapists licensed in specified state' do
        results = Therapist.by_state('CA')
        expect(results).to include(ca_therapist)
        expect(results).not_to include(tx_therapist)
      end
    end

    describe '.with_specialization' do
      it 'returns therapists with specified specialization' do
        results = Therapist.with_specialization('anxiety')
        expect(results).to include(therapist_with_anxiety)
        expect(results).not_to include(active_therapist)
      end

      it 'returns distinct therapists' do
        therapist = create(:therapist)
        create(:therapist_specialization, therapist: therapist, specialization: 'anxiety')
        create(:therapist_specialization, therapist: therapist, specialization: 'depression')

        results = Therapist.with_specialization('anxiety')
        expect(results.where(id: therapist.id).count).to eq(1)
      end
    end
  end

  describe 'instance methods' do
    let(:therapist) { create(:therapist, first_name: 'Jane', last_name: 'Doe') }

    describe '#full_name' do
      it 'returns first and last name combined' do
        expect(therapist.full_name).to eq('Jane Doe')
      end
    end

    describe '#specializations' do
      it 'returns array of specialization strings' do
        create(:therapist_specialization, therapist: therapist, specialization: 'anxiety')
        create(:therapist_specialization, therapist: therapist, specialization: 'depression')

        expect(therapist.specializations).to contain_exactly('anxiety', 'depression')
      end

      it 'returns empty array when no specializations' do
        expect(therapist.specializations).to eq([])
      end
    end
  end

  describe 'array fields' do
    let(:therapist) do
      create(:therapist,
             languages: %w[en es],
             age_ranges: %w[5-12 13-17],
             treatment_modalities: %w[cbt dbt emdr])
    end

    it 'stores and retrieves languages array' do
      expect(therapist.reload.languages).to eq(%w[en es])
    end

    it 'stores and retrieves age_ranges array' do
      expect(therapist.reload.age_ranges).to eq(%w[5-12 13-17])
    end

    it 'stores and retrieves treatment_modalities array' do
      expect(therapist.reload.treatment_modalities).to eq(%w[cbt dbt emdr])
    end
  end

  describe 'defaults' do
    let(:therapist) { Therapist.create!(first_name: 'John', last_name: 'Doe') }

    it 'defaults active to true' do
      expect(therapist.active).to be true
    end

    it 'defaults languages to empty array' do
      expect(therapist.languages).to eq([])
    end

    it 'defaults age_ranges to empty array' do
      expect(therapist.age_ranges).to eq([])
    end

    it 'defaults treatment_modalities to empty array' do
      expect(therapist.treatment_modalities).to eq([])
    end
  end
end
