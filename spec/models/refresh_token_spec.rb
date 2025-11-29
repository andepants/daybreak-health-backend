# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RefreshToken, type: :model do
  describe 'associations' do
    it { should belong_to(:onboarding_session) }
  end

  describe 'validations' do
    subject { build(:refresh_token) }

    it 'validates presence of token_hash' do
      refresh_token = build(:refresh_token)
      refresh_token.token = nil # Clear the token to prevent hashing
      refresh_token.token_hash = nil # Clear the hash explicitly
      expect(refresh_token).not_to be_valid
      expect(refresh_token.errors[:token_hash]).to include("can't be blank")
    end

    it { should validate_presence_of(:expires_at) }
    it { should validate_presence_of(:device_fingerprint) }

    it 'validates uniqueness of token_hash' do
      # Create first token with explicit hash
      token1 = create(:refresh_token)

      # Try to create second token with same hash
      token2 = build(:refresh_token)
      token2.token = nil # Prevent auto-hashing
      token2.token_hash = token1.token_hash

      expect(token2).not_to be_valid
      expect(token2.errors[:token_hash]).to include('has already been taken')
    end
  end

  describe 'scopes' do
    let(:session) { create(:onboarding_session) }

    describe '.valid' do
      it 'includes non-revoked, non-expired tokens' do
        valid_token = create(:refresh_token, :valid, onboarding_session: session)
        expired_token = create(:refresh_token, :expired, onboarding_session: session)
        revoked_token = create(:refresh_token, :revoked, onboarding_session: session)

        expect(RefreshToken.valid).to include(valid_token)
        expect(RefreshToken.valid).not_to include(expired_token)
        expect(RefreshToken.valid).not_to include(revoked_token)
      end
    end

    describe '.expired' do
      it 'includes tokens past expiration time' do
        valid_token = create(:refresh_token, :valid, onboarding_session: session)
        expired_token = create(:refresh_token, :expired, onboarding_session: session)

        expect(RefreshToken.expired).to include(expired_token)
        expect(RefreshToken.expired).not_to include(valid_token)
      end
    end

    describe '.revoked' do
      it 'includes revoked tokens' do
        valid_token = create(:refresh_token, :valid, onboarding_session: session)
        revoked_token = create(:refresh_token, :revoked, onboarding_session: session)

        expect(RefreshToken.revoked).to include(revoked_token)
        expect(RefreshToken.revoked).not_to include(valid_token)
      end
    end
  end

  describe 'token hashing (AC 2.6.2)' do
    it 'hashes token with bcrypt before saving' do
      plaintext = SecureRandom.urlsafe_base64(64)
      refresh_token = build(:refresh_token, plaintext_token: plaintext)

      expect(refresh_token.token_hash).to be_nil # Not hashed until save

      refresh_token.save!

      # After save, token should be hashed
      expect(refresh_token.token_hash).to be_present
      expect(refresh_token.token_hash).not_to eq(plaintext)
      expect(refresh_token.token_hash).to match(/\A\$2a\$/) # bcrypt format
    end

    it 'raises error if token is not set before saving' do
      refresh_token = build(:refresh_token)
      refresh_token.token = nil # Clear the token

      expect {
        refresh_token.save!
      }.to raise_error(ActiveRecord::RecordInvalid)

      expect(refresh_token.errors[:token_hash]).to include("can't be blank")
    end
  end

  describe '#token_matches?' do
    it 'returns true for matching token' do
      plaintext = SecureRandom.urlsafe_base64(64)
      refresh_token = create(:refresh_token, plaintext_token: plaintext)

      expect(refresh_token.token_matches?(plaintext)).to be true
    end

    it 'returns false for non-matching token' do
      plaintext = SecureRandom.urlsafe_base64(64)
      refresh_token = create(:refresh_token, plaintext_token: plaintext)

      expect(refresh_token.token_matches?('wrong-token')).to be false
    end

    it 'handles invalid hash gracefully' do
      refresh_token = create(:refresh_token)
      refresh_token.update_column(:token_hash, 'invalid-hash')

      expect(refresh_token.token_matches?('any-token')).to be false
    end
  end

  describe '#valid_token?' do
    it 'returns true for non-revoked, non-expired token' do
      refresh_token = create(:refresh_token, :valid)
      expect(refresh_token.valid_token?).to be true
    end

    it 'returns false for expired token' do
      refresh_token = create(:refresh_token, :expired)
      expect(refresh_token.valid_token?).to be false
    end

    it 'returns false for revoked token' do
      refresh_token = create(:refresh_token, :revoked)
      expect(refresh_token.valid_token?).to be false
    end

    it 'returns false for revoked and expired token' do
      refresh_token = create(:refresh_token, expires_at: 1.day.ago, revoked_at: 1.hour.ago)
      expect(refresh_token.valid_token?).to be false
    end
  end

  describe '#revoke!' do
    it 'sets revoked_at timestamp' do
      freeze_time do
        refresh_token = create(:refresh_token, :valid)

        expect(refresh_token.revoked_at).to be_nil

        refresh_token.revoke!

        expect(refresh_token.revoked_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'makes valid_token? return false after revocation' do
      refresh_token = create(:refresh_token, :valid)

      expect(refresh_token.valid_token?).to be true

      refresh_token.revoke!

      expect(refresh_token.valid_token?).to be false
    end
  end

  describe '#expired?' do
    it 'returns true if token has passed expiration time' do
      refresh_token = create(:refresh_token, :expired)
      expect(refresh_token.expired?).to be true
    end

    it 'returns false if token has not expired' do
      refresh_token = create(:refresh_token, :valid)
      expect(refresh_token.expired?).to be false
    end
  end

  describe '#revoked?' do
    it 'returns true if token has been revoked' do
      refresh_token = create(:refresh_token, :revoked)
      expect(refresh_token.revoked?).to be true
    end

    it 'returns false if token has not been revoked' do
      refresh_token = create(:refresh_token, :valid)
      expect(refresh_token.revoked?).to be false
    end
  end

  describe 'device fingerprint tracking' do
    it 'stores device fingerprint for tracking' do
      fingerprint = Digest::SHA256.hexdigest('device-info')
      refresh_token = create(:refresh_token, device_fingerprint: fingerprint)

      expect(refresh_token.device_fingerprint).to eq(fingerprint)
    end

    it 'stores IP address for audit trail' do
      ip = '192.168.1.100'
      refresh_token = create(:refresh_token, ip_address: ip)

      expect(refresh_token.ip_address).to eq(ip)
    end

    it 'stores user agent for audit trail' do
      user_agent = 'Mozilla/5.0 (Test)'
      refresh_token = create(:refresh_token, user_agent: user_agent)

      expect(refresh_token.user_agent).to eq(user_agent)
    end
  end
end
