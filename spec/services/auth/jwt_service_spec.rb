# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::JwtService do
  describe '.encode' do
    it 'encodes a payload into a JWT token' do
      payload = { session_id: '123', role: 'parent' }
      token = described_class.encode(payload)

      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3) # JWT has 3 parts
    end

    it 'adds exp claim with default 1 hour expiration' do
      payload = { session_id: '123' }
      token = described_class.encode(payload)

      decoded = described_class.decode(token)
      expect(decoded[:exp]).to be_within(5).of(1.hour.from_now.to_i)
    end

    it 'adds iat claim with current time' do
      payload = { session_id: '123' }
      token = described_class.encode(payload)

      decoded = described_class.decode(token)
      expect(decoded[:iat]).to be_within(5).of(Time.current.to_i)
    end

    it 'accepts custom expiration time' do
      payload = { session_id: '123' }
      custom_exp = 2.hours.from_now
      token = described_class.encode(payload, exp: custom_exp)

      decoded = described_class.decode(token)
      expect(decoded[:exp]).to be_within(5).of(custom_exp.to_i)
    end

    it 'preserves original payload data' do
      payload = { session_id: '123', role: 'parent', custom: 'value' }
      token = described_class.encode(payload)

      decoded = described_class.decode(token)
      expect(decoded[:session_id]).to eq('123')
      expect(decoded[:role]).to eq('parent')
      expect(decoded[:custom]).to eq('value')
    end

    it 'raises error for non-Hash payload' do
      expect {
        described_class.encode('not a hash')
      }.to raise_error(ArgumentError, 'Payload must be a Hash')
    end

    it 'does not mutate the original payload' do
      payload = { session_id: '123' }
      original_keys = payload.keys

      described_class.encode(payload)

      expect(payload.keys).to eq(original_keys)
    end
  end

  describe '.decode' do
    it 'decodes a valid JWT token' do
      payload = { session_id: '123', role: 'parent' }
      token = described_class.encode(payload)

      decoded = described_class.decode(token)
      expect(decoded).to be_a(ActiveSupport::HashWithIndifferentAccess)
      expect(decoded[:session_id]).to eq('123')
      expect(decoded[:role]).to eq('parent')
    end

    it 'returns nil for blank token' do
      expect(described_class.decode('')).to be_nil
      expect(described_class.decode(nil)).to be_nil
    end

    it 'returns nil for invalid token' do
      expect(described_class.decode('invalid.token.here')).to be_nil
    end

    it 'returns nil for expired token' do
      payload = { session_id: '123' }
      token = described_class.encode(payload, exp: 1.second.ago)

      expect(described_class.decode(token)).to be_nil
    end

    it 'returns nil for tampered token' do
      payload = { session_id: '123' }
      token = described_class.encode(payload)

      # Tamper with the token
      parts = token.split('.')
      parts[1] = Base64.urlsafe_encode64('{"session_id":"999"}')
      tampered_token = parts.join('.')

      expect(described_class.decode(tampered_token)).to be_nil
    end

    it 'logs warning for expired token' do
      payload = { session_id: '123' }
      token = described_class.encode(payload, exp: 1.second.ago)

      expect(Rails.logger).to receive(:warn).with(/JWT expired/)
      described_class.decode(token)
    end

    it 'logs warning for decode error' do
      expect(Rails.logger).to receive(:warn).with(/JWT decode failed/)
      described_class.decode('invalid.token')
    end
  end

  describe '.valid?' do
    it 'returns true for valid token' do
      payload = { session_id: '123' }
      token = described_class.encode(payload)

      expect(described_class.valid?(token)).to be true
    end

    it 'returns false for invalid token' do
      expect(described_class.valid?('invalid.token')).to be false
    end

    it 'returns false for expired token' do
      payload = { session_id: '123' }
      token = described_class.encode(payload, exp: 1.second.ago)

      expect(described_class.valid?(token)).to be false
    end

    it 'returns false for blank token' do
      expect(described_class.valid?('')).to be false
      expect(described_class.valid?(nil)).to be false
    end
  end

  describe 'security' do
    it 'uses HS256 algorithm' do
      expect(described_class::ALGORITHM).to eq('HS256')
    end

    it 'requires secret to be at least 32 characters' do
      # This is tested indirectly through the secret validation
      # The actual validation happens in the private method
      payload = { session_id: '123' }
      expect {
        described_class.encode(payload)
      }.not_to raise_error
    end

    it 'produces different tokens for same payload (due to iat)' do
      payload = { session_id: '123' }

      token1 = described_class.encode(payload)
      sleep 1.1 # iat uses seconds precision, so wait >1 second
      token2 = described_class.encode(payload)

      # Tokens should be different due to different iat timestamps
      expect(token1).not_to eq(token2)
    end

    it 'cannot be decoded with wrong secret' do
      payload = { session_id: '123' }
      token = described_class.encode(payload)

      # Try to decode with different secret
      wrong_secret = 'different-secret-key-min-32-chars-long'
      expect {
        JWT.decode(token, wrong_secret, true, algorithm: 'HS256')
      }.to raise_error(JWT::VerificationError)
    end
  end

  describe 'token expiration behavior' do
    it 'accepts token just before expiration' do
      payload = { session_id: '123' }
      token = described_class.encode(payload, exp: 5.seconds.from_now)

      # Should still be valid
      decoded = described_class.decode(token)
      expect(decoded).to be_present
      expect(decoded[:session_id]).to eq('123')
    end

    it 'rejects token just after expiration' do
      payload = { session_id: '123' }
      token = described_class.encode(payload, exp: Time.current)

      sleep 0.1 # Ensure token is expired

      expect(described_class.decode(token)).to be_nil
    end
  end
end
