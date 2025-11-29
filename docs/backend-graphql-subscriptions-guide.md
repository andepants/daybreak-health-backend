# Backend Integration Guide: GraphQL Subscriptions via Action Cable

**From:** Frontend Team
**To:** Backend Team
**Date:** 2025-11-28
**Topic:** Enabling Real-time GraphQL Subscriptions for Support Chat (P1 Feature)

---

## Overview

The frontend is using **Apollo Client** for all GraphQL operations. To support real-time features (like the support chat), we need GraphQL subscriptions working over WebSockets.

**Good news:** We can use Rails' existing **Action Cable** as the WebSocket transport - no need for a separate WebSocket server or Redis (for MVP).

---

## What We Need

The frontend expects to use this subscription (already in `api_schema.graphql`):

```graphql
type Subscription {
  supportChatMessages(onboardingSessionId: ID!): ChatMessage
}

type ChatMessage {
  id: ID!
  sender: MessageSender!
  content: String!
  timestamp: String!
}
```

---

## Backend Implementation Steps

### Step 1: Add graphql-ruby Subscription Support

Add to your `Gemfile` (if not already present):

```ruby
gem 'graphql', '~> 2.0'
```

### Step 2: Configure Schema for Action Cable Subscriptions

Update your GraphQL schema to use Action Cable as the subscription transport:

```ruby
# app/graphql/your_schema.rb (e.g., ParentOnboardingSchema)

class ParentOnboardingSchema < GraphQL::Schema
  # Add this line to enable Action Cable subscriptions
  use GraphQL::Subscriptions::ActionCableSubscriptions

  mutation(Types::MutationType)
  query(Types::QueryType)
  subscription(Types::SubscriptionType)  # Add if not present
end
```

### Step 3: Create the Subscription Type

```ruby
# app/graphql/types/subscription_type.rb

module Types
  class SubscriptionType < Types::BaseObject
    field :support_chat_messages, Types::ChatMessageType, null: true do
      argument :onboarding_session_id, ID, required: true
      description "Subscribe to new messages in a support chat session"
    end

    def support_chat_messages(onboarding_session_id:)
      # This is called when a message is triggered
      # The object is passed from the trigger call
      object
    end
  end
end
```

### Step 4: Create the GraphQL Channel

```ruby
# app/channels/graphql_channel.rb

class GraphqlChannel < ApplicationCable::Channel
  def subscribed
    @subscription_ids = []
  end

  def execute(data)
    query = data["query"]
    variables = ensure_hash(data["variables"])
    operation_name = data["operationName"]

    context = {
      channel: self,
      current_user: current_user  # From Action Cable connection
    }

    result = ParentOnboardingSchema.execute(
      query: query,
      variables: variables,
      context: context,
      operation_name: operation_name
    )

    payload = {
      result: result.to_h,
      more: result.subscription?
    }

    @subscription_ids << result.context[:subscription_id] if result.context[:subscription_id]

    transmit(payload)
  end

  def unsubscribed
    @subscription_ids.each do |sid|
      ParentOnboardingSchema.subscriptions.delete_subscription(sid)
    end
  end

  private

  def ensure_hash(ambiguous_param)
    case ambiguous_param
    when String
      ambiguous_param.present? ? ensure_hash(JSON.parse(ambiguous_param)) : {}
    when Hash
      ambiguous_param
    when ActionController::Parameters
      ambiguous_param.to_unsafe_h
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{ambiguous_param}"
    end
  end
end
```

### Step 5: Configure Action Cable Connection (if not already done)

```ruby
# app/channels/application_cable/connection.rb

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Extract JWT from query params or headers
      token = request.params[:token] || request.headers["Authorization"]&.split(" ")&.last

      if token.present?
        # Decode JWT and find user
        decoded = JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: 'HS256')
        User.find(decoded[0]["user_id"])
      else
        reject_unauthorized_connection
      end
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      reject_unauthorized_connection
    end
  end
end
```

### Step 6: Trigger Subscriptions When Events Occur

When a new support chat message is created, trigger the subscription:

```ruby
# app/services/support_chat_service.rb (or wherever messages are created)

class SupportChatService
  def self.send_message(onboarding_session_id:, sender:, content:)
    message = ChatMessage.create!(
      onboarding_session_id: onboarding_session_id,
      sender: sender,
      content: content
    )

    # Trigger the GraphQL subscription
    ParentOnboardingSchema.subscriptions.trigger(
      :support_chat_messages,
      { onboarding_session_id: onboarding_session_id },
      message  # This becomes `object` in the subscription resolver
    )

    message
  end
end
```

Or in your mutation:

```ruby
# app/graphql/mutations/send_support_chat_message.rb

module Mutations
  class SendSupportChatMessage < BaseMutation
    argument :onboarding_session_id, ID, required: true
    argument :content, String, required: true

    field :chat_message, Types::ChatMessageType, null: true

    def resolve(onboarding_session_id:, content:)
      message = ChatMessage.create!(
        onboarding_session_id: onboarding_session_id,
        sender: context[:current_user].role,  # PARENT, SUPPORT, etc.
        content: content
      )

      # Trigger subscription for all listeners
      ParentOnboardingSchema.subscriptions.trigger(
        :support_chat_messages,
        { onboarding_session_id: onboarding_session_id },
        message
      )

      { chat_message: message }
    end
  end
end
```

### Step 7: Mount the Cable Route

Ensure Action Cable is mounted in your routes:

```ruby
# config/routes.rb

Rails.application.routes.draw do
  mount ActionCable.server => '/cable'

  # ... other routes
end
```

---

## Configuration Files

### config/cable.yml (Development)

For MVP, you can use the async adapter (no Redis needed):

```yaml
development:
  adapter: async

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: parent_onboarding_production
```

### For Production (Aptible)

If you want to avoid Redis initially, consider [Solid Cable](https://github.com/rails/solid_cable):

```ruby
# Gemfile
gem 'solid_cable'
```

```yaml
# config/cable.yml
production:
  adapter: solid_cable
  polling_interval: 0.1.seconds
```

---

## CORS Configuration

Ensure WebSocket connections from the frontend domain are allowed:

```ruby
# config/initializers/cors.rb

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('FRONTEND_URL', 'http://localhost:3000')

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end

# config/environments/production.rb
config.action_cable.allowed_request_origins = [
  ENV.fetch('FRONTEND_URL'),
  /https:\/\/.*\.daybreakhealth\.com/
]
```

---

## Testing the Subscription

### Using GraphQL Playground/GraphiQL

```graphql
subscription {
  supportChatMessages(onboardingSessionId: "123") {
    id
    sender
    content
    timestamp
  }
}
```

### Using wscat (Command Line)

```bash
# Install wscat
npm install -g wscat

# Connect
wscat -c "ws://localhost:3001/cable"

# Subscribe
{"command":"subscribe","identifier":"{\"channel\":\"GraphqlChannel\"}"}

# Execute subscription
{"command":"message","identifier":"{\"channel\":\"GraphqlChannel\"}","data":"{\"query\":\"subscription { supportChatMessages(onboardingSessionId: \\\"123\\\") { id content } }\"}"}
```

---

## Frontend Connection Details

The frontend will connect using:

```typescript
// Frontend uses graphql-ws library
const wsLink = new GraphQLWsLink(
  createClient({
    url: 'ws://localhost:3001/cable',
    connectionParams: {
      token: authToken  // JWT for authentication
    }
  })
)
```

---

## Summary Checklist

- [ ] Add `use GraphQL::Subscriptions::ActionCableSubscriptions` to schema
- [ ] Create `Types::SubscriptionType` with `support_chat_messages` field
- [ ] Create `GraphqlChannel` to handle subscription operations
- [ ] Update `ApplicationCable::Connection` for JWT auth
- [ ] Add subscription triggers where messages are created
- [ ] Configure CORS for WebSocket connections
- [ ] Test with GraphQL playground or wscat

---

## Questions?

If you have questions about the expected data format or subscription behavior, refer to:
- `docs/api_schema.graphql` - The complete GraphQL schema contract
- `docs/frontend_prd.md` - Frontend technical specification

The frontend team is available to pair on integration testing.
