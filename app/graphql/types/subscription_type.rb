# frozen_string_literal: true

module Types
  class SubscriptionType < Types::BaseObject
    field :session_updated, subscription: Subscriptions::SessionUpdated
  end
end
