# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insurance, type: :model do
  describe 'associations' do
    it { should belong_to(:onboarding_session) }
  end

  describe 'validations' do
    it { should validate_presence_of(:payer_name) }
    it { should validate_presence_of(:subscriber_name) }
    it { should validate_presence_of(:member_id) }
    it { should validate_presence_of(:verification_status) }
    it { should validate_presence_of(:onboarding_session) }
  end

  describe 'enums' do
    it do
      should define_enum_for(:verification_status)
        .with_values(
          pending: 0,
          in_progress: 1,
          verified: 2,
          failed: 3,
          manual_review: 4,
          self_pay: 5
        )
    end

    it 'has all 6 verification_status values' do
      expect(Insurance.verification_statuses.keys).to contain_exactly(
        'pending', 'in_progress', 'verified', 'failed', 'manual_review', 'self_pay'
      )
    end
  end

  describe 'PHI encryption' do
    let(:insurance) do
      create(:insurance,
             subscriber_name: 'John Doe',
             member_id: 'MEM123',
             policy_number: 'ABC123',
             group_number: 'GRP001',
             card_image_front: 'front_image_data',
             card_image_back: 'back_image_data')
    end

    it 'encrypts subscriber_name field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT subscriber_name FROM insurances WHERE id = '#{insurance.id}'"
      ).first['subscriber_name']
      expect(raw_value).not_to eq('John Doe')
    end

    it 'decrypts subscriber_name field when accessed' do
      expect(insurance.subscriber_name).to eq('John Doe')
    end

    it 'encrypts member_id field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT member_id FROM insurances WHERE id = '#{insurance.id}'"
      ).first['member_id']
      expect(raw_value).not_to eq('MEM123')
    end

    it 'encrypts policy_number field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT policy_number FROM insurances WHERE id = '#{insurance.id}'"
      ).first['policy_number']
      expect(raw_value).not_to eq('ABC123')
    end

    it 'encrypts group_number field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT group_number FROM insurances WHERE id = '#{insurance.id}'"
      ).first['group_number']
      expect(raw_value).not_to eq('GRP001')
    end

    it 'encrypts card_image_front field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT card_image_front FROM insurances WHERE id = '#{insurance.id}'"
      ).first['card_image_front']
      expect(raw_value).not_to eq('front_image_data')
    end

    it 'encrypts card_image_back field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT card_image_back FROM insurances WHERE id = '#{insurance.id}'"
      ).first['card_image_back']
      expect(raw_value).not_to eq('back_image_data')
    end
  end

  describe 'UUID primary key' do
    it 'generates UUID for id' do
      insurance = create(:insurance)
      expect(insurance.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end

  describe 'timestamps' do
    it 'sets created_at and updated_at' do
      insurance = create(:insurance)
      expect(insurance.created_at).to be_present
      expect(insurance.updated_at).to be_present
    end
  end
end
