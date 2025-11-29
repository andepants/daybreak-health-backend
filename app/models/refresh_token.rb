# frozen_string_literal: true

# RefreshToken model for secure token storage
#
# Stores refresh tokens for session persistence with enhanced security:
# - Tokens are hashed with bcrypt before storage (never stored in plaintext)
# - Device fingerprinting for tracking which device issued the token
# - IP address and user agent for audit trail
# - Revocation support with revoked_at timestamp (soft delete)
# - Expiration after 7 days
#
# Example usage:
#   token = RefreshToken.create!(
#     onboarding_session: session,
#     token: SecureRandom.urlsafe_base64(64),
#     device_fingerprint: Digest::SHA256.hexdigest(user_agent + ip),
#     ip_address: request.ip,
#     user_agent: request.user_agent,
#     expires_at: 7.days.from_now
#   )
class RefreshToken < ApplicationRecord
  belongs_to :onboarding_session

  # Validations
  validates :token_hash, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :device_fingerprint, presence: true

  # Scopes
  scope :valid, -> { where(revoked_at: nil).where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :revoked, -> { where.not(revoked_at: nil) }

  # Virtual attribute for the plaintext token (never persisted)
  attr_accessor :token

  # Hash the token before validation (must run before validation checks token_hash presence)
  before_validation :hash_token, on: :create, if: -> { token.present? }

  # Verify if a plaintext token matches this record's hash
  #
  # @param plaintext_token [String] The plaintext token to verify
  # @return [Boolean] true if token matches
  def token_matches?(plaintext_token)
    return false if token_hash.blank?
    BCrypt::Password.new(token_hash) == plaintext_token
  rescue BCrypt::Errors::InvalidHash
    false
  end

  # Check if token is valid (not revoked and not expired)
  #
  # @return [Boolean] true if token is valid
  def valid_token?
    revoked_at.nil? && expires_at > Time.current
  end

  # Revoke this token (soft delete)
  #
  # @return [Boolean] true if revocation was successful
  def revoke!
    update!(revoked_at: Time.current)
  end

  # Check if token is expired
  #
  # @return [Boolean] true if token has passed expiration time
  def expired?
    expires_at <= Time.current
  end

  # Check if token is revoked
  #
  # @return [Boolean] true if token has been revoked
  def revoked?
    revoked_at.present?
  end

  private

  # Hash the token using bcrypt before saving
  # The plaintext token is in the virtual @token attribute
  # Skip hashing if token is blank to avoid errors
  def hash_token
    return if token.blank?
    self.token_hash = BCrypt::Password.create(token)
  end
end
