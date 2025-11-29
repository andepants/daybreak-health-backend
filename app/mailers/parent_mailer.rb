# frozen_string_literal: true

# Mailer for parent-facing emails
#
# Handles all email communications sent to parents during the onboarding process,
# including session recovery magic links.
class ParentMailer < ApplicationMailer
  # Send session recovery email with magic link
  #
  # @param parent [Parent] Parent to send email to
  # @param recovery_url [String] Magic link URL with recovery token
  #
  # @example
  #   ParentMailer.session_recovery(
  #     parent: parent,
  #     recovery_url: "https://app.daybreak.health/recover?token=abc123"
  #   ).deliver_later
  def session_recovery(parent:, recovery_url:)
    @parent = parent
    @recovery_url = recovery_url
    @expiration_minutes = 15

    mail(
      to: parent.email,
      subject: 'Continue your Daybreak onboarding'
    )
  end
end
