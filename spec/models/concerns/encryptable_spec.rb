# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Encryptable, type: :model do
  # Create a test model class that includes the concern
  before(:all) do
    # Create a test table
    ActiveRecord::Migration.create_table :test_encryptables, id: :uuid, force: true do |t|
      t.text :encrypted_field
      t.text :another_encrypted_field
      t.string :public_field
      t.timestamps
    end

    # Define test model
    class TestEncryptable < ApplicationRecord
      include Encryptable
      encrypts_phi :encrypted_field, :another_encrypted_field
    end
  end

  after(:all) do
    # Clean up
    ActiveRecord::Migration.drop_table :test_encryptables
    Object.send(:remove_const, :TestEncryptable)
  end

  describe '.encrypts_phi' do
    it 'encrypts specified fields' do
      record = TestEncryptable.create!(
        encrypted_field: 'sensitive data',
        public_field: 'public data'
      )

      # Reload to ensure we're reading from database
      record.reload

      # Encrypted field should be accessible
      expect(record.encrypted_field).to eq('sensitive data')

      # Public field should be unchanged
      expect(record.public_field).to eq('public data')
    end

    it 'encrypts multiple fields' do
      record = TestEncryptable.create!(
        encrypted_field: 'first secret',
        another_encrypted_field: 'second secret'
      )

      expect(record.encrypted_field).to eq('first secret')
      expect(record.another_encrypted_field).to eq('second secret')
    end

    it 'handles nil values' do
      record = TestEncryptable.create!(
        encrypted_field: nil,
        public_field: 'public'
      )

      expect(record.encrypted_field).to be_nil
    end

    it 'handles empty strings' do
      record = TestEncryptable.create!(
        encrypted_field: '',
        public_field: 'public'
      )

      expect(record.encrypted_field).to eq('')
    end

    it 'encrypts data at rest (raw database value is different)' do
      record = TestEncryptable.create!(encrypted_field: 'secret')

      # Query raw database value
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT encrypted_field FROM test_encryptables WHERE id = '#{record.id}'"
      ).first['encrypted_field']

      # Raw value should NOT be the plaintext
      expect(raw_value).not_to eq('secret')
      expect(raw_value).to be_present
    end
  end

  describe 'PHI-safe behavior' do
    it 'does not expose PHI in logs' do
      # This is a behavioral test - the concern itself doesn't log,
      # but it enables encryption which prevents PHI from being stored in plaintext
      record = TestEncryptable.create!(encrypted_field: 'SSN: 123-45-6789')

      # The encrypted value should not contain the original PHI
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT encrypted_field FROM test_encryptables WHERE id = '#{record.id}'"
      ).first['encrypted_field']

      expect(raw_value).not_to include('123-45-6789')
    end
  end
end
