# frozen_string_literal: true

# Content Security Policy (CSP) Configuration
#
# Defines security headers to prevent XSS, clickjacking, and other attacks.
# Be cautious when adding directives - CSP is security-critical.
#
# Rails API-only applications typically don't need CSP headers since they
# don't serve HTML directly. However, if this API serves any HTML pages
# (like GraphiQL in development) or if CSP headers are needed for compliance,
# this configuration can be used.
#
# Story 7.1: Intercom widget integration requires allowing Intercom domains
# for script, connect, frame, and img sources.

# Only configure CSP if needed (e.g., for GraphiQL in development or specific compliance needs)
Rails.application.config.content_security_policy do |policy|
  # Allow scripts from self and Intercom
  policy.script_src :self, :https, "https://widget.intercom.io", "https://js.intercomcdn.com"

  # Allow connections to self and Intercom
  policy.connect_src :self, :https, "https://*.intercom.io", "wss://*.intercom.io"

  # Allow frames from Intercom
  policy.frame_src :self, "https://*.intercom.io"

  # Allow images from self, data URIs, and Intercom
  policy.img_src :self, :data, :https, "https://*.intercom.io", "https://*.intercomcdn.com"

  # Allow styles from self and inline (for GraphiQL and Intercom)
  policy.style_src :self, :unsafe_inline, "https://*.intercomcdn.com"

  # Allow fonts from self and Intercom
  policy.font_src :self, :data, "https://*.intercomcdn.com"
end

# Generate session nonces for permitted importmap and inline scripts
# Rails.application.config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
# Rails.application.config.content_security_policy_nonce_directives = %w(script-src)

# Report violations in development
if Rails.env.development?
  Rails.application.config.content_security_policy_report_only = true
end
