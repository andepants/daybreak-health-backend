# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::RecoveryTokenService, type: :service do
  let(:redis) { Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')) }
  let(:session) { create(:onboarding_session) }
  let(:session_id) { session.id }

  before do
    # Clear Redis test keys before each test
    redis.keys('session_recovery:*').each { |key| redis.del(key) }
  end

  after do
    # Clear Redis test keys after each test
    redis.keys('session_recovery:*').each { |key| redis.del(key) }
  end

  describe '.generate' do
    it 'generates a secure random token' do
      token = described_class.generate(session_id)

      expect(token).to be_present
      expect(token).to be_a(String)
      # urlsafe_base64(32) produces ~43 characters
      expect(token.length).to be >= 40
    end

    it 'stores token in Redis with 15-minute TTL' do
      token = described_class.generate(session_id)

      key = "session_recovery:#{session_id}"
      stored_token = redis.get(key)
      ttl = redis.ttl(key)

      expect(stored_token).to eq(token)
      expect(ttl).to be_within(5).of(15.minutes.to_i)
    end

    it 'generates unique tokens for each call' do
      token1 = described_class.generate(session_id)
      token2 = described_class.generate(session_id)

      expect(token1).not_to eq(token2)
    end

    it 'overwrites previous token for same session' do
      token1 = described_class.generate(session_id)
      token2 = described_class.generate(session_id)

      key = "session_recovery:#{session_id}"
      stored_token = redis.get(key)

      expect(stored_token).to eq(token2)
      expect(stored_token).not_to eq(token1)
    end
  end

  describe '.valid?' do
    it 'returns true for valid token' do
      token = described_class.generate(session_id)

      expect(described_class.valid?(session_id, token)).to be true
    end

    it 'returns false for invalid token' do
      described_class.generate(session_id)

      expect(described_class.valid?(session_id, 'invalid_token')).to be false
    end

    it 'returns false for blank token' do
      described_class.generate(session_id)

      expect(described_class.valid?(session_id, '')).to be false
      expect(described_class.valid?(session_id, nil)).to be false
    end

    it 'returns false for wrong session_id' do
      token = described_class.generate(session_id)
      other_session_id = SecureRandom.uuid

      expect(described_class.valid?(other_session_id, token)).to be false
    end

    it 'returns false for expired token' do
      token = described_class.generate(session_id)

      # Simulate expiration by deleting from Redis
      key = "session_recovery:#{session_id}"
      redis.del(key)

      expect(described_class.valid?(session_id, token)).to be false
    end

    it 'does not delete token (non-consuming)' do
      token = described_class.generate(session_id)

      # Multiple validations should succeed
      expect(described_class.valid?(session_id, token)).to be true
      expect(described_class.valid?(session_id, token)).to be true
      expect(described_class.valid?(session_id, token)).to be true
    end
  end

  describe '.consume' do
    it 'returns true for valid token and deletes it' do
      token = described_class.generate(session_id)

      expect(described_class.consume(session_id, token)).to be true

      # Token should be deleted (one-time use)
      expect(described_class.valid?(session_id, token)).to be false
    end

    it 'returns false for invalid token' do
      described_class.generate(session_id)

      expect(described_class.consume(session_id, 'invalid_token')).to be false
    end

    it 'returns false for blank token' do
      described_class.generate(session_id)

      expect(described_class.consume(session_id, '')).to be false
      expect(described_class.consume(session_id, nil)).to be false
    end

    it 'returns false on second consumption (one-time use)' do
      token = described_class.generate(session_id)

      # First consumption succeeds
      expect(described_class.consume(session_id, token)).to be true

      # Second consumption fails (token already consumed)
      expect(described_class.consume(session_id, token)).to be false
    end
  end

  describe '.revoke' do
    it 'returns true and deletes existing token' do
      described_class.generate(session_id)

      expect(described_class.revoke(session_id)).to be true

      # Token should be deleted
      key = "session_recovery:#{session_id}"
      expect(redis.get(key)).to be_nil
    end

    it 'returns false when no token exists' do
      expect(described_class.revoke(session_id)).to be false
    end

    it 'invalidates the token' do
      token = described_class.generate(session_id)
      described_class.revoke(session_id)

      expect(described_class.valid?(session_id, token)).to be false
    end
  end

  describe 'HIPAA security considerations' do
    it 'uses cryptographically secure token generation' do
      # SecureRandom.urlsafe_base64(32) provides 256 bits of randomness
      tokens = 100.times.map { described_class.generate(session_id) }

      # All tokens should be unique
      expect(tokens.uniq.length).to eq(100)
    end

    it 'token cannot be guessed from session_id' do
      token = described_class.generate(session_id)

      # Token should not contain session_id
      expect(token).not_to include(session_id.to_s.gsub('-', ''))
    end

    it 'has short TTL for security' do
      described_class.generate(session_id)

      key = "session_recovery:#{session_id}"
      ttl = redis.ttl(key)

      # TTL should be 15 minutes or less
      expect(ttl).to be <= 15.minutes.to_i
    end
  end
end
