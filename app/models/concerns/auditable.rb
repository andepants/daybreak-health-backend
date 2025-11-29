# frozen_string_literal: true

# Auditable concern for automatic audit logging
#
# This concern adds audit logging capabilities to models
# by creating AuditLog entries on create, update, and destroy events.
#
# PHI-Safe: Never logs actual PHI values, only existence flags and metadata
#
# Example usage:
#   class Parent < ApplicationRecord
#     include Auditable
#   end
#
# Note: Requires an AuditLog model and current actor tracking
module Auditable
  extend ActiveSupport::Concern

  included do
    after_create :log_creation
    after_update :log_update
    after_destroy :log_deletion
  end

  private

  def log_creation
    create_audit_log('CREATE', changes: redacted_changes)
  end

  def log_update
    return unless saved_changes.any?

    create_audit_log('UPDATE', changes: redacted_changes)
  end

  def log_deletion
    create_audit_log('DELETE', final_state: redacted_attributes)
  end

  def create_audit_log(action, details = {})
    AuditLog.create!(
      onboarding_session_id: audit_session_id,
      user_id: audit_user_id,
      action: action,
      resource: self.class.name,
      resource_id: id,
      details: details,
      ip_address: audit_ip_address,
      user_agent: audit_user_agent
    )
  rescue StandardError => e
    # Log audit failure but don't prevent the main operation
    Rails.logger.error("Audit logging failed for #{self.class.name}##{id}: #{e.message}")
  end

  # Get session ID for audit log (from association or Thread.current)
  def audit_session_id
    # First try association
    if respond_to?(:onboarding_session_id) && onboarding_session_id.present?
      return onboarding_session_id
    end

    if respond_to?(:onboarding_session) && onboarding_session.present?
      return onboarding_session.id
    end

    # Fall back to Thread.current
    Thread.current[:current_session]&.id
  end

  # Get user ID for audit log (from Thread.current)
  def audit_user_id
    user = Thread.current[:current_user]
    return nil unless user

    user.respond_to?(:id) ? user.id : user[:id]
  end

  # Get IP address for audit log (from Thread.current)
  def audit_ip_address
    Thread.current[:current_ip_address]
  end

  # Get user agent for audit log (from Thread.current)
  def audit_user_agent
    Thread.current[:current_user_agent]
  end

  # Redact PHI fields from changes hash
  # Only log existence flags, never actual values
  def redacted_changes
    changes_hash = saved_changes.presence || changes
    return {} if changes_hash.blank?

    changes_hash.each_with_object({}) do |(field_name, change_array), result|
      field_name = field_name.to_s
      # For PHI fields, only log presence/absence
      if phi_field?(field_name)
        result[field_name] = [change_array[0].present? ? '[REDACTED]' : nil, change_array[1].present? ? '[REDACTED]' : nil]
      else
        result[field_name] = change_array
      end
    end
  end

  # Redact PHI fields from attributes hash
  def redacted_attributes
    return {} unless respond_to?(:attributes)

    attributes.each_with_object({}) do |(field_name, value), result|
      field_name = field_name.to_s
      result[field_name] = phi_field?(field_name) ? (value.present? ? '[REDACTED]' : nil) : value
    end
  end

  # Check if a specific field contains PHI based on model's encrypted attributes
  # @param field_name [String, Symbol] The field name to check
  # @return [Boolean] true if field is encrypted (PHI)
  def phi_field?(field_name)
    return false unless self.class.respond_to?(:encrypted_attributes)
    return false if self.class.encrypted_attributes.blank?

    # Check if this specific field is in the encrypted attributes list
    field_name = field_name.to_sym if field_name.is_a?(String)
    self.class.encrypted_attributes.include?(field_name)
  end
end
