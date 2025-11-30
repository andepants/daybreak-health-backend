# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Support::IntercomService do
  let(:session_id) { SecureRandom.uuid }
  let(:app_id) { 'test_app_123' }
  let(:secret_key) { 'a' * 32 } # 32-char secret key

  before do
    # Set Intercom environment variables
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('INTERCOM_APP_ID').and_return(app_id)
    allow(ENV).to receive(:[]).with('INTERCOM_SECRET_KEY').and_return(secret_key)
    allow(ENV).to receive(:[]).with('INTERCOM_ENABLED').and_return('true')
  end

  describe '#initialize' do
    it 'initializes with a session_id' do
      service = described_class.new(session_id: session_id)
      expect(service.session_id).to eq(session_id)
    end

    it 'raises error when session_id is blank' do
      expect {
        described_class.new(session_id: '')
      }.to raise_error(ArgumentError, 'session_id cannot be blank')
    end

    it 'raises error when session_id is nil' do
      expect {
        described_class.new(session_id: nil)
      }.to raise_error(ArgumentError, 'session_id cannot be blank')
    end
  end

  describe '#call' do
    subject(:result) { described_class.new(session_id: session_id).call }

    context 'when Intercom is enabled and configured' do
      it 'returns identity verification data' do
        expect(result).to be_a(Hash)
        expect(result.keys).to match_array([:app_id, :user_hash, :user_id, :enabled])
      end

      it 'returns the app_id from environment' do
        expect(result[:app_id]).to eq(app_id)
      end

      it 'returns the session_id as user_id' do
        expect(result[:user_id]).to eq(session_id)
      end

      it 'generates HMAC-SHA256 hash as user_hash' do
        expected_hash = OpenSSL::HMAC.hexdigest(
          OpenSSL::Digest.new('sha256'),
          secret_key,
          session_id
        )

        expect(result[:user_hash]).to eq(expected_hash)
      end

      it 'marks Intercom as enabled' do
        expect(result[:enabled]).to be true
      end

      it 'generates different hashes for different session IDs' do
        result1 = described_class.new(session_id: 'session-1').call
        result2 = described_class.new(session_id: 'session-2').call

        expect(result1[:user_hash]).not_to eq(result2[:user_hash])
      end

      it 'generates consistent hash for same session ID' do
        result1 = described_class.new(session_id: session_id).call
        result2 = described_class.new(session_id: session_id).call

        expect(result1[:user_hash]).to eq(result2[:user_hash])
      end
    end

    context 'when Intercom is disabled' do
      before do
        allow(ENV).to receive(:[]).with('INTERCOM_APP_ID').and_return(nil)
        allow(ENV).to receive(:[]).with('INTERCOM_SECRET_KEY').and_return(nil)
        allow(ENV).to receive(:[]).with('INTERCOM_ENABLED').and_return(nil)
      end

      it 'returns enabled: false' do
        expect(result[:enabled]).to be false
      end

      it 'returns nil for user_hash' do
        expect(result[:user_hash]).to be_nil
      end
    end

    context 'when app_id is missing' do
      before do
        allow(ENV).to receive(:[]).with('INTERCOM_APP_ID').and_return(nil)
      end

      it 'returns enabled: false' do
        expect(result[:enabled]).to be false
      end
    end

    context 'when secret_key is missing' do
      before do
        allow(ENV).to receive(:[]).with('INTERCOM_SECRET_KEY').and_return(nil)
      end

      it 'returns enabled: false' do
        expect(result[:enabled]).to be false
      end

      it 'returns nil for user_hash' do
        expect(result[:user_hash]).to be_nil
      end
    end

    context 'when secret_key is too short' do
      before do
        allow(ENV).to receive(:[]).with('INTERCOM_SECRET_KEY').and_return('short-key')
      end

      it 'returns enabled: false' do
        expect(result[:enabled]).to be false
      end

      it 'returns nil for user_hash' do
        expect(result[:user_hash]).to be_nil
      end
    end
  end

  describe '.call' do
    it 'is a class method convenience wrapper' do
      result = described_class.call(session_id: session_id)
      expect(result).to be_a(Hash)
      expect(result[:user_id]).to eq(session_id)
    end
  end

  describe 'HIPAA compliance' do
    it 'only uses session ID as identifier (no PHI)' do
      result = described_class.new(session_id: session_id).call

      # Verify we're not passing any PHI
      expect(result[:user_id]).to eq(session_id) # Only session ID
      expect(result.keys).not_to include(:name, :email, :phone, :dob)
    end

    it 'uses secure HMAC-SHA256 for identity verification' do
      result = described_class.new(session_id: session_id).call

      # Verify the hash is a valid hex string (64 chars for SHA256)
      expect(result[:user_hash]).to match(/\A[a-f0-9]{64}\z/)
    end
  end

  describe 'security considerations' do
    it 'disables Intercom when secret key is less than 32 characters' do
      allow(ENV).to receive(:[]).with('INTERCOM_SECRET_KEY').and_return('a' * 31)

      result = described_class.new(session_id: session_id).call
      expect(result[:enabled]).to be false
      expect(result[:user_hash]).to be_nil
    end

    it 'enables Intercom with secret key of exactly 32 characters' do
      allow(ENV).to receive(:[]).with('INTERCOM_SECRET_KEY').and_return('a' * 32)

      result = described_class.new(session_id: session_id).call
      expect(result[:enabled]).to be true
      expect(result[:user_hash]).to be_present
    end

    it 'enables Intercom with secret key longer than 32 characters' do
      allow(ENV).to receive(:[]).with('INTERCOM_SECRET_KEY').and_return('a' * 64)

      result = described_class.new(session_id: session_id).call
      expect(result[:enabled]).to be true
      expect(result[:user_hash]).to be_present
    end

    it 'accepts base64-encoded secret keys' do
      base64_key = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=='
      allow(ENV).to receive(:[]).with('INTERCOM_SECRET_KEY').and_return(base64_key)

      result = described_class.new(session_id: session_id).call
      expect(result[:enabled]).to be true
      expect(result[:user_hash]).to be_present
    end

    it 'accepts secret keys with hyphens and underscores' do
      key_with_special = 'abc123-def456_ghi789-jkl012_mno345pqr678'
      allow(ENV).to receive(:[]).with('INTERCOM_SECRET_KEY').and_return(key_with_special)

      result = described_class.new(session_id: session_id).call
      expect(result[:enabled]).to be true
      expect(result[:user_hash]).to be_present
    end

    it 'rejects secret keys with invalid characters' do
      invalid_key = 'invalid-key-with-special-chars!@#$%^&*()'
      allow(ENV).to receive(:[]).with('INTERCOM_SECRET_KEY').and_return(invalid_key)

      result = described_class.new(session_id: session_id).call
      expect(result[:enabled]).to be false
      expect(result[:user_hash]).to be_nil
    end

    it 'rejects secret keys with spaces' do
      key_with_spaces = 'this is a secret key with spaces that is longer than 32 chars'
      allow(ENV).to receive(:[]).with('INTERCOM_SECRET_KEY').and_return(key_with_spaces)

      result = described_class.new(session_id: session_id).call
      expect(result[:enabled]).to be false
      expect(result[:user_hash]).to be_nil
    end
  end

  describe 'test environment behavior' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))
    end

    context 'when INTERCOM_ENABLED is not set' do
      before do
        allow(ENV).to receive(:[]).with('INTERCOM_ENABLED').and_return(nil)
      end

      it 'disables Intercom by default in test' do
        result = described_class.new(session_id: session_id).call
        expect(result[:enabled]).to be false
      end
    end

    context 'when INTERCOM_ENABLED is explicitly true' do
      before do
        allow(ENV).to receive(:[]).with('INTERCOM_ENABLED').and_return('true')
      end

      it 'enables Intercom when configuration is present' do
        result = described_class.new(session_id: session_id).call
        expect(result[:enabled]).to be true
      end
    end
  end
end
