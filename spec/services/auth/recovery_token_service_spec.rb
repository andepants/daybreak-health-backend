# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::RecoveryTokenService, type: :service do
  let(:redis) { Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')) }
  let(:session) { create(:onboarding_session, :with_parent) }
  let(:parent) { session.parent }
  let(:email) { parent.email }

  before do
    # Clear Redis before each test
    redis.flushdb
  end

  after do
    # Clear Redis after each test
    redis.flushdb
  end

  describe '.generate_recovery_token' do
    it 'generates a secure random token' do
      token = described_class.generate_recovery_token(
        session_id: session.id,
        email: email
      )

      expect(token).to be_present
      expect(token).to be_a(String)
      expect(token.length).to eq(64) # 32 bytes = 64 hex characters
    end

    it 'stores token in Redis with 15-minute TTL' do
      token = described_class.generate_recovery_token(
        session_id: session.id,
        email: email
      )

      key = "recovery:#{token}"
      stored_session_id = redis.get(key)
      ttl = redis.ttl(key)

      expect(stored_session_id).to eq(session.id)
      expect(ttl).to be_within(5).of(15.minutes.to_i)
    end

    it 'increments rate limit counter' do
      expect {
        described_class.generate_recovery_token(
          session_id: session.id,
          email: email
        )
      }.to change {
        described_class.rate_limit_count(email)
      }.from(0).to(1)
    end

    it 'raises error when session_id is blank' do
      expect {
        described_class.generate_recovery_token(
          session_id: '',
          email: email
        )
      }.to raise_error(ArgumentError, 'Session ID must be present')
    end

    it 'raises error when email is blank' do
      expect {
        described_class.generate_recovery_token(
          session_id: session.id,
          email: ''
        )
      }.to raise_error(ArgumentError, 'Email must be present')
    end

    context 'rate limiting' do
      it 'allows up to 3 requests within the rate limit window' do
        expect {
          3.times do
            described_class.generate_recovery_token(
              session_id: session.id,
              email: email
            )
          end
        }.not_to raise_error
      end

      it 'blocks 4th request within the hour' do
        # Generate 3 tokens (at the limit)
        3.times do
          described_class.generate_recovery_token(
            session_id: session.id,
            email: email
          )
        end

        # 4th request should fail
        expect {
          described_class.generate_recovery_token(
            session_id: session.id,
            email: email
          )
        }.to raise_error(
          Auth::RecoveryTokenService::RateLimitExceededError,
          'Too many recovery requests. Please try again later.'
        )
      end

      it 'is case-insensitive for email' do
        # Generate 3 tokens with lowercase email
        3.times do
          described_class.generate_recovery_token(
            session_id: session.id,
            email: email.downcase
          )
        end

        # 4th request with uppercase email should also fail
        expect {
          described_class.generate_recovery_token(
            session_id: session.id,
            email: email.upcase
          )
        }.to raise_error(Auth::RecoveryTokenService::RateLimitExceededError)
      end
    end
  end

  describe '.validate_recovery_token' do
    let(:token) do
      described_class.generate_recovery_token(
        session_id: session.id,
        email: email
      )
    end

    it 'returns session_id for valid token' do
      session_id = described_class.validate_recovery_token(token)

      expect(session_id).to eq(session.id)
    end

    it 'deletes token after successful validation (one-time use)' do
      # First validation should succeed
      session_id = described_class.validate_recovery_token(token)
      expect(session_id).to eq(session.id)

      # Second validation should fail (token deleted)
      session_id = described_class.validate_recovery_token(token)
      expect(session_id).to be_nil
    end

    it 'returns nil for invalid token' do
      session_id = described_class.validate_recovery_token('invalid_token')

      expect(session_id).to be_nil
    end

    it 'returns nil for blank token' do
      session_id = described_class.validate_recovery_token('')

      expect(session_id).to be_nil
    end

    it 'returns nil for expired token' do
      # Generate token
      token = described_class.generate_recovery_token(
        session_id: session.id,
        email: email
      )

      # Simulate token expiration by deleting from Redis
      key = "recovery:#{token}"
      redis.del(key)

      session_id = described_class.validate_recovery_token(token)

      expect(session_id).to be_nil
    end
  end

  describe '.rate_limit_exceeded?' do
    it 'returns false when under limit' do
      expect(described_class.rate_limit_exceeded?(email)).to be false
    end

    it 'returns true when at limit' do
      3.times do
        described_class.generate_recovery_token(
          session_id: session.id,
          email: email
        )
      end

      expect(described_class.rate_limit_exceeded?(email)).to be true
    end

    it 'returns false for blank email' do
      expect(described_class.rate_limit_exceeded?('')).to be false
    end
  end

  describe '.rate_limit_count' do
    it 'returns 0 when no requests made' do
      expect(described_class.rate_limit_count(email)).to eq(0)
    end

    it 'returns correct count after requests' do
      2.times do
        described_class.generate_recovery_token(
          session_id: session.id,
          email: email
        )
      end

      expect(described_class.rate_limit_count(email)).to eq(2)
    end

    it 'returns 0 for blank email' do
      expect(described_class.rate_limit_count('')).to eq(0)
    end
  end
end
