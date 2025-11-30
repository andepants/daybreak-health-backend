# frozen_string_literal: true

module Types
  class SubscriptionType < Types::BaseObject
    field :session_updated, subscription: Subscriptions::SessionUpdated
    field :message_received, subscription: Subscriptions::MessageReceived
    field :progress_updated, subscription: Subscriptions::ProgressUpdated
    field :insurance_status_changed, subscription: Subscriptions::InsuranceStatusChanged
    # Story 5.1: Assessment progress updates
    field :assessment_updated, subscription: Subscriptions::AssessmentUpdated
  end
end
