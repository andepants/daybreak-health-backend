# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Parent, type: :model do
  describe 'associations' do
    it { should belong_to(:onboarding_session) }
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:phone) }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:relationship) }
    it { should validate_presence_of(:onboarding_session) }

    it 'validates email format' do
      parent = build(:parent, email: 'invalid-email')
      expect(parent).not_to be_valid
      expect(parent.errors[:email]).to be_present
    end

    it 'validates phone format' do
      parent = build(:parent, phone: 'invalid-phone')
      expect(parent).not_to be_valid
      expect(parent.errors[:phone]).to be_present
    end

    it 'validates is_guardian is boolean' do
      parent = build(:parent, is_guardian: nil)
      expect(parent).not_to be_valid
      expect(parent.errors[:is_guardian]).to be_present
    end
  end

  describe 'PHI encryption' do
    let(:parent) { create(:parent, email: 'test@example.com', first_name: 'John', last_name: 'Doe', phone: '+1234567890') }

    it 'encrypts email field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT email FROM parents WHERE id = '#{parent.id}'"
      ).first['email']
      expect(raw_value).not_to eq('test@example.com')
    end

    it 'decrypts email field when accessed' do
      expect(parent.email).to eq('test@example.com')
    end

    it 'encrypts first_name field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT first_name FROM parents WHERE id = '#{parent.id}'"
      ).first['first_name']
      expect(raw_value).not_to eq('John')
    end

    it 'encrypts last_name field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT last_name FROM parents WHERE id = '#{parent.id}'"
      ).first['last_name']
      expect(raw_value).not_to eq('Doe')
    end

    it 'encrypts phone field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT phone FROM parents WHERE id = '#{parent.id}'"
      ).first['phone']
      expect(raw_value).not_to eq('+1234567890')
    end
  end

  describe 'UUID primary key' do
    it 'generates UUID for id' do
      parent = create(:parent)
      expect(parent.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end

  describe 'timestamps' do
    it 'sets created_at and updated_at' do
      parent = create(:parent)
      expect(parent.created_at).to be_present
      expect(parent.updated_at).to be_present
    end
  end
end
