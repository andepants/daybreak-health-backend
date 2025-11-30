# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TherapistSpecialization, type: :model do
  describe 'associations' do
    it { should belong_to(:therapist) }
  end

  describe 'validations' do
    let(:therapist) { create(:therapist) }
    subject { build(:therapist_specialization, therapist: therapist) }

    it { should validate_presence_of(:specialization) }

    describe 'uniqueness' do
      it 'validates uniqueness of specialization scoped to therapist' do
        create(:therapist_specialization, therapist: therapist, specialization: 'anxiety')
        duplicate = build(:therapist_specialization, therapist: therapist, specialization: 'anxiety')

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:specialization]).to include('has already been taken')
      end

      it 'allows same specialization for different therapists' do
        therapist1 = create(:therapist)
        therapist2 = create(:therapist)

        create(:therapist_specialization, therapist: therapist1, specialization: 'anxiety')
        duplicate = build(:therapist_specialization, therapist: therapist2, specialization: 'anxiety')

        expect(duplicate).to be_valid
      end
    end
  end

  describe 'creating specializations' do
    let(:therapist) { create(:therapist) }

    it 'can create multiple specializations for a therapist' do
      specializations = %w[anxiety depression adhd trauma]

      specializations.each do |spec|
        create(:therapist_specialization, therapist: therapist, specialization: spec)
      end

      expect(therapist.therapist_specializations.count).to eq(4)
      expect(therapist.specializations).to match_array(specializations)
    end
  end

  describe 'dependent destroy' do
    it 'is destroyed when therapist is destroyed' do
      therapist = create(:therapist, :with_specializations)
      specialization_ids = therapist.therapist_specializations.pluck(:id)

      therapist.destroy

      specialization_ids.each do |id|
        expect(TherapistSpecialization.find_by(id: id)).to be_nil
      end
    end
  end
end
