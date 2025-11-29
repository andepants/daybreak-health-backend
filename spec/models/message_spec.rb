# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message, type: :model do
  describe 'associations' do
    it { should belong_to(:onboarding_session) }
  end

  describe 'validations' do
    it { should validate_presence_of(:role) }
    it { should validate_presence_of(:content) }
    it { should validate_presence_of(:onboarding_session) }
  end

  describe 'enums' do
    it do
      should define_enum_for(:role)
        .with_values(
          user: 0,
          assistant: 1,
          system: 2
        )
    end

    it 'has all 3 role values' do
      expect(Message.roles.keys).to contain_exactly('user', 'assistant', 'system')
    end
  end

  describe 'PHI encryption' do
    let(:message) { create(:message, content: 'Sensitive message content') }

    it 'encrypts content field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT content FROM messages WHERE id = '#{message.id}'"
      ).first['content']
      expect(raw_value).not_to eq('Sensitive message content')
    end

    it 'decrypts content field when accessed' do
      expect(message.content).to eq('Sensitive message content')
    end
  end

  describe 'UUID primary key' do
    it 'generates UUID for id' do
      message = create(:message)
      expect(message.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end

  describe 'timestamps' do
    it 'sets created_at and updated_at' do
      message = create(:message)
      expect(message.created_at).to be_present
      expect(message.updated_at).to be_present
    end
  end
end
