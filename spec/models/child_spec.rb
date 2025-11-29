# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Child, type: :model do
  describe 'associations' do
    it { should belong_to(:onboarding_session) }
  end

  describe 'validations' do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:date_of_birth) }
    it { should validate_presence_of(:gender) }
    it { should validate_presence_of(:onboarding_session) }
  end

  describe 'PHI encryption' do
    let(:child) { create(:child, first_name: 'Jane', last_name: 'Doe', date_of_birth: '2010-05-15') }

    it 'encrypts first_name field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT first_name FROM children WHERE id = '#{child.id}'"
      ).first['first_name']
      expect(raw_value).not_to eq('Jane')
    end

    it 'decrypts first_name field when accessed' do
      expect(child.first_name).to eq('Jane')
    end

    it 'encrypts last_name field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT last_name FROM children WHERE id = '#{child.id}'"
      ).first['last_name']
      expect(raw_value).not_to eq('Doe')
    end

    it 'encrypts date_of_birth field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT date_of_birth FROM children WHERE id = '#{child.id}'"
      ).first['date_of_birth']
      expect(raw_value).not_to eq('2010-05-15')
    end
  end

  describe 'UUID primary key' do
    it 'generates UUID for id' do
      child = create(:child)
      expect(child.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end

  describe 'timestamps' do
    it 'sets created_at and updated_at' do
      child = create(:child)
      expect(child.created_at).to be_present
      expect(child.updated_at).to be_present
    end
  end
end
