# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::TokenService do
  let(:session) { create(:onboarding_session) }
  let(:device_fingerprint) { Digest::SHA256.hexdigest('test-device-123') }
  let(:ip_address) { '192.168.1.1' }
  let(:user_agent) { 'Mozilla/5.0 (Test Browser)' }

  describe '.generate_refresh_token' do
    it 'generates a token string' do
      token = described_class.generate_refresh_token(
        session,
        device_fingerprint: device_fingerprint,
        ip_address: ip_address,
        user_agent: user_agent
      )

      expect(token).to be_a(String)
      expect(token.length).to be > 0
    end

    it 'generates unique tokens' do
      token1 = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)
      token2 = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)

      expect(token1).not_to eq(token2)
    end

    it 'creates RefreshToken record in database' do
      token = described_class.generate_refresh_token(
        session,
        device_fingerprint: device_fingerprint,
        ip_address: ip_address,
        user_agent: user_agent
      )

      refresh_token = session.refresh_tokens.order(created_at: :desc).first
      expect(refresh_token.onboarding_session).to eq(session)
      expect(refresh_token.device_fingerprint).to eq(device_fingerprint)
      expect(refresh_token.ip_address).to eq(ip_address)
      expect(refresh_token.user_agent).to eq(user_agent)
    end

    it 'stores token hash, not plaintext' do
      token = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)

      refresh_token = session.refresh_tokens.order(created_at: :desc).first
      # Token hash should not match plaintext
      expect(refresh_token.token_hash).not_to eq(token)
      # Should be bcrypt hash
      expect(refresh_token.token_hash).to match(/\A\$2a\$/)
    end

    it 'sets token expiration to 7 days from now' do
      freeze_time do
        described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)

        refresh_token = session.refresh_tokens.order(created_at: :desc).first
        expect(refresh_token.expires_at).to be_within(1.second).of(7.days.from_now)
      end
    end

    it 'raises error for non-OnboardingSession' do
      expect {
        described_class.generate_refresh_token('not a session', device_fingerprint: device_fingerprint)
      }.to raise_error(ArgumentError, 'Session must be an OnboardingSession')
    end

    it 'raises error for unpersisted session' do
      new_session = build(:onboarding_session)

      expect {
        described_class.generate_refresh_token(new_session, device_fingerprint: device_fingerprint)
      }.to raise_error(ArgumentError, 'Session must be persisted')
    end

    it 'raises error when device_fingerprint is missing' do
      expect {
        described_class.generate_refresh_token(session, device_fingerprint: nil)
      }.to raise_error(ArgumentError, 'Device fingerprint is required')
    end
  end

  describe '.validate_refresh_token' do
    let!(:token) do
      described_class.generate_refresh_token(
        session,
        device_fingerprint: device_fingerprint,
        ip_address: ip_address,
        user_agent: user_agent
      )
    end

    it 'returns session and new token for valid token' do
      result = described_class.validate_refresh_token(
        token,
        device_fingerprint: device_fingerprint,
        ip_address: ip_address,
        user_agent: user_agent
      )

      expect(result).to be_a(Hash)
      expect(result[:session]).to eq(session)
      expect(result[:new_token]).to be_a(String)
      expect(result[:new_token]).not_to eq(token) # New token is different
    end

    it 'returns nil for invalid token' do
      result = described_class.validate_refresh_token(
        'invalid-token',
        device_fingerprint: device_fingerprint
      )
      expect(result).to be_nil
    end

    it 'returns nil for blank token' do
      expect(described_class.validate_refresh_token('', device_fingerprint: device_fingerprint)).to be_nil
      expect(described_class.validate_refresh_token(nil, device_fingerprint: device_fingerprint)).to be_nil
    end

    it 'returns nil for expired token' do
      refresh_token = session.refresh_tokens.order(created_at: :desc).first
      refresh_token.update!(expires_at: 1.day.ago)

      result = described_class.validate_refresh_token(token, device_fingerprint: device_fingerprint)
      expect(result).to be_nil
    end

    it 'returns nil for revoked token' do
      refresh_token = session.refresh_tokens.order(created_at: :desc).first
      refresh_token.revoke!

      result = described_class.validate_refresh_token(token, device_fingerprint: device_fingerprint)
      expect(result).to be_nil
    end

    it 'returns nil if session was deleted' do
      session.destroy!

      result = described_class.validate_refresh_token(token, device_fingerprint: device_fingerprint)
      expect(result).to be_nil
    end
  end

  describe 'token rotation (AC 2.6.2)' do
    it 'revokes old token after successful validation' do
      token = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)

      # First validation succeeds and creates new token
      result1 = described_class.validate_refresh_token(token, device_fingerprint: device_fingerprint)
      expect(result1[:session]).to eq(session)

      # Second validation with same token fails (token was revoked)
      result2 = described_class.validate_refresh_token(token, device_fingerprint: device_fingerprint)
      expect(result2).to be_nil
    end

    it 'marks token as revoked in database after validation' do
      token = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)
      refresh_token = session.refresh_tokens.order(created_at: :desc).first

      expect(refresh_token.revoked_at).to be_nil

      described_class.validate_refresh_token(token, device_fingerprint: device_fingerprint)

      refresh_token.reload
      expect(refresh_token.revoked_at).to be_present
    end

    it 'generates new token with same device fingerprint on rotation' do
      token = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)

      result = described_class.validate_refresh_token(
        token,
        device_fingerprint: device_fingerprint,
        ip_address: '192.168.1.2',
        user_agent: 'New Browser'
      )

      new_refresh_token = RefreshToken.order(created_at: :desc).first
      expect(new_refresh_token.device_fingerprint).to eq(device_fingerprint)
      expect(new_refresh_token.ip_address).to eq('192.168.1.2')
      expect(new_refresh_token.user_agent).to eq('New Browser')
    end

    it 'allows using new token after rotation' do
      token = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)

      # First rotation
      result1 = described_class.validate_refresh_token(token, device_fingerprint: device_fingerprint)
      new_token = result1[:new_token]

      # Second rotation with new token should work
      result2 = described_class.validate_refresh_token(new_token, device_fingerprint: device_fingerprint)
      expect(result2[:session]).to eq(session)
      expect(result2[:new_token]).to be_present
    end
  end

  describe '.invalidate_token' do
    it 'revokes token in database' do
      token = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)
      refresh_token = session.refresh_tokens.order(created_at: :desc).first

      result = described_class.invalidate_token(token)
      expect(result).to be true

      # Token should be revoked
      refresh_token.reload
      expect(refresh_token.revoked_at).to be_present
    end

    it 'returns false for non-existent token' do
      result = described_class.invalidate_token('non-existent-token')
      expect(result).to be false
    end

    it 'returns false for blank token' do
      expect(described_class.invalidate_token('')).to be false
      expect(described_class.invalidate_token(nil)).to be false
    end

    it 'prevents subsequent validation after invalidation' do
      token = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)

      described_class.invalidate_token(token)

      result = described_class.validate_refresh_token(token, device_fingerprint: device_fingerprint)
      expect(result).to be_nil
    end
  end

  describe '.invalidate_all_tokens' do
    it 'revokes all tokens for a session' do
      token1 = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)
      token2 = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)
      token3 = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)

      count = described_class.invalidate_all_tokens(session)
      expect(count).to eq(3)

      # All tokens should be revoked
      session.refresh_tokens.each do |rt|
        expect(rt.revoked_at).to be_present
      end

      # All tokens should be invalid
      expect(described_class.validate_refresh_token(token1, device_fingerprint: device_fingerprint)).to be_nil
      expect(described_class.validate_refresh_token(token2, device_fingerprint: device_fingerprint)).to be_nil
      expect(described_class.validate_refresh_token(token3, device_fingerprint: device_fingerprint)).to be_nil
    end

    it 'does not affect tokens from other sessions' do
      other_session = create(:onboarding_session)

      session_token = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)
      other_token = described_class.generate_refresh_token(other_session, device_fingerprint: device_fingerprint)

      described_class.invalidate_all_tokens(session)

      # Other session's token should still be valid
      result = described_class.validate_refresh_token(other_token, device_fingerprint: device_fingerprint)
      expect(result[:session]).to eq(other_session)
    end

    it 'returns 0 if session has no tokens' do
      count = described_class.invalidate_all_tokens(session)
      expect(count).to eq(0)
    end

    it 'does not count already revoked tokens' do
      token1 = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)
      token2 = described_class.generate_refresh_token(session, device_fingerprint: device_fingerprint)

      # Revoke one token
      described_class.invalidate_token(token1)

      # Should only count non-revoked tokens
      count = described_class.invalidate_all_tokens(session)
      expect(count).to eq(1)
    end
  end

  describe '.cleanup_expired_tokens' do
    it 'deletes tokens expired more than 90 days ago' do
      # Create a fresh session for this test
      cleanup_session = create(:onboarding_session)

      # Create token that expired 91 days ago
      old_token = described_class.generate_refresh_token(cleanup_session, device_fingerprint: device_fingerprint)
      cleanup_session.refresh_tokens.order(created_at: :desc).first.update!(expires_at: 91.days.ago)

      # Create token that expired 89 days ago (should NOT be deleted)
      recent_token = described_class.generate_refresh_token(cleanup_session, device_fingerprint: device_fingerprint)
      cleanup_session.refresh_tokens.order(created_at: :desc).first.update!(expires_at: 89.days.ago)

      # Create valid token (should NOT be deleted)
      valid_token = described_class.generate_refresh_token(cleanup_session, device_fingerprint: device_fingerprint)

      initial_count = cleanup_session.refresh_tokens.count
      expect(initial_count).to eq(3)

      deleted_count = described_class.cleanup_expired_tokens

      # Only old token should be deleted
      expect(deleted_count).to eq(1)
      expect(cleanup_session.refresh_tokens.reload.count).to eq(2)
      expect(RefreshToken.where('expires_at < ?', 90.days.ago).count).to eq(0)
    end

    it 'returns count of deleted tokens' do
      # Create a fresh session for this test
      cleanup_session = create(:onboarding_session)

      3.times do
        token = described_class.generate_refresh_token(cleanup_session, device_fingerprint: device_fingerprint)
        cleanup_session.refresh_tokens.order(created_at: :desc).first.update!(expires_at: 91.days.ago)
      end

      count = described_class.cleanup_expired_tokens
      expect(count).to eq(3)
    end
  end

  describe 'security' do
    it 'generates cryptographically secure tokens' do
      # Use a fresh session to avoid pollution
      security_session = create(:onboarding_session)
      token = described_class.generate_refresh_token(security_session, device_fingerprint: device_fingerprint)

      # Token should be URL-safe base64
      expect(token).to match(/\A[A-Za-z0-9_-]+\z/)

      # Token should be sufficiently long
      expect(token.length).to be >= 64
    end

    it 'tokens are unpredictable' do
      # Use a fresh session to avoid pollution
      security_session = create(:onboarding_session)
      tokens = 100.times.map { described_class.generate_refresh_token(security_session, device_fingerprint: device_fingerprint) }

      # All tokens should be unique
      expect(tokens.uniq.length).to eq(100)
    end

    it 'tokens are hashed with bcrypt (AC 2.6.2)' do
      # Use a fresh session to avoid pollution
      security_session = create(:onboarding_session)
      token = described_class.generate_refresh_token(security_session, device_fingerprint: device_fingerprint)

      refresh_token = security_session.refresh_tokens.order(created_at: :desc).first
      # Should be bcrypt hash format
      expect(refresh_token.token_hash).to match(/\A\$2a\$\d{2}\$/)

      # Verify hash matches token
      expect(refresh_token.token_matches?(token)).to be true
      expect(refresh_token.token_matches?('wrong_token')).to be false
    end

    it 'device fingerprint is stored for tracking' do
      # Create a fresh session for this test to avoid pollution
      test_session = create(:onboarding_session)

      fingerprint1 = Digest::SHA256.hexdigest('device1')
      fingerprint2 = Digest::SHA256.hexdigest('device2')

      token1 = described_class.generate_refresh_token(test_session, device_fingerprint: fingerprint1)
      token2 = described_class.generate_refresh_token(test_session, device_fingerprint: fingerprint2)

      rt1 = test_session.refresh_tokens.order(created_at: :asc).first
      rt2 = test_session.refresh_tokens.order(created_at: :asc).last

      expect(rt1.device_fingerprint).to eq(fingerprint1)
      expect(rt2.device_fingerprint).to eq(fingerprint2)
    end
  end
end
