# frozen_string_literal: true

# Intercom Configuration
#
# Configures Intercom integration for customer support widget.
# Validates environment variables and provides configuration access.
#
# Required Environment Variables:
# - INTERCOM_APP_ID: Intercom workspace app ID (public)
# - INTERCOM_SECRET_KEY: Secret key for identity verification (min 32 chars)
# - INTERCOM_ENABLED: Enable/disable integration (optional, defaults to false in test)
#
# Security:
# - Identity verification prevents user impersonation via HMAC-SHA256
# - Secret key must be >= 32 characters for security
# - No PHI is transmitted to Intercom (session IDs only)
#
# HIPAA Compliance:
# - Requires signed BAA with Intercom before production use
# - Only non-PHI metadata passed to Intercom
# - Intercom HIPAA plan must be configured

Rails.application.configure do
  config.intercom = ActiveSupport::OrderedOptions.new

  # App ID (public configuration)
  config.intercom.app_id = ENV['INTERCOM_APP_ID']

  # Secret key for identity verification (private)
  config.intercom.secret_key = ENV['INTERCOM_SECRET_KEY']

  # Enable/disable Intercom
  # Disabled by default in test environment
  config.intercom.enabled = if Rails.env.test?
                              ENV['INTERCOM_ENABLED'] == 'true'
                            else
                              config.intercom.app_id.present? && config.intercom.secret_key.present?
                            end

  # Validate configuration in non-test environments
  unless Rails.env.test?
    if config.intercom.enabled
      # Validate app ID is present
      if config.intercom.app_id.blank?
        Rails.logger.warn('[Intercom] INTERCOM_APP_ID not configured - widget will be disabled')
        config.intercom.enabled = false
      end

      # Validate secret key is present and secure
      if config.intercom.secret_key.blank?
        Rails.logger.warn('[Intercom] INTERCOM_SECRET_KEY not configured - widget will be disabled')
        config.intercom.enabled = false
      elsif config.intercom.secret_key.length < 32
        Rails.logger.error('[Intercom] INTERCOM_SECRET_KEY must be at least 32 characters')
        config.intercom.enabled = false
      end

      if config.intercom.enabled
        # Only log app_id prefix in non-production environments for security
        if Rails.env.production?
          Rails.logger.info('[Intercom] Initialized successfully (identity verification enabled)')
        else
          Rails.logger.info('[Intercom] Initialized successfully with app_id: ' \
                            "#{config.intercom.app_id[0..7]}... (identity verification enabled)")
        end
      end
    else
      Rails.logger.info('[Intercom] Disabled - set INTERCOM_APP_ID and INTERCOM_SECRET_KEY to enable')
    end
  end
end
