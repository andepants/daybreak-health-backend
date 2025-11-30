# Story 7.3: Support Request Tracking

Status: ready-for-dev

## Story

As a **system**,
I want **to track support requests and link them to onboarding sessions**,
So that **we can analyze support needs and improve the flow**.

## Acceptance Criteria

**Given** parent interacts with support
**When** chat is initiated or completed
**Then**
1. Support request logged in our database
2. Fields captured: `session_id`, `timestamp`, `source` (widget location), `resolved`
3. Intercom conversation ID stored for reference
4. Session flagged as "contacted support"
5. Analytics: support requests by onboarding step
6. Webhook receives Intercom events (optional)

**And** support patterns inform UX improvements
**And** follow-up possible via session link

## Tasks / Subtasks

- [ ] Task 1: Create SupportRequest model (AC: #1, #2, #3, #4)
  - [ ] Generate migration for `support_requests` table
  - [ ] Add fields: `onboarding_session_id` (uuid, foreign key), `intercom_conversation_id` (string), `source` (string), `resolved` (boolean, default: false), `timestamps`
  - [ ] Add index on `onboarding_session_id`
  - [ ] Add index on `created_at` for analytics queries
  - [ ] Define model with associations: `belongs_to :onboarding_session`
  - [ ] Add validations: presence of `onboarding_session_id`, `source`
  - [ ] Run migration and verify schema

- [ ] Task 2: Implement Intercom webhook integration (AC: #6, #1, #2, #3)
  - [ ] Create webhook controller: `app/controllers/webhooks/intercom_controller.rb`
  - [ ] Add route: `post '/webhooks/intercom', to: 'webhooks/intercom#create'`
  - [ ] Verify Intercom webhook signature for security
  - [ ] Handle `conversation.user.created` event - create SupportRequest record
  - [ ] Handle `conversation.user.replied` event - update timestamps
  - [ ] Handle `conversation.admin.closed` event - mark `resolved: true`
  - [ ] Extract session_id from custom attributes or metadata
  - [ ] Store Intercom conversation ID in support_requests table
  - [ ] Handle errors gracefully (log and return 200 to prevent retries)

- [ ] Task 3: Flag session when support is contacted (AC: #4)
  - [ ] Add migration: add `contacted_support` boolean column to `onboarding_sessions` (default: false)
  - [ ] Update OnboardingSession model to include new field
  - [ ] In webhook handler, update `session.update(contacted_support: true)` when support request created
  - [ ] Run migration and verify

- [ ] Task 4: Create GraphQL query for support requests (AC: #7 - follow-up via session link)
  - [ ] Create `Types::SupportRequestType` with fields: `id`, `sessionId`, `intercomConversationId`, `source`, `resolved`, `createdAt`, `updatedAt`
  - [ ] Add query to QueryType: `supportRequests(sessionId: ID!): [SupportRequest!]!`
  - [ ] Implement resolver to fetch support requests for given session
  - [ ] Add authorization check (session owner or admin only)
  - [ ] Test query in GraphiQL

- [ ] Task 5: Implement analytics query for support hotspots (AC: #5)
  - [ ] Create service: `app/services/analytics/support_analytics_service.rb`
  - [ ] Implement method: `requests_by_onboarding_step` - group support requests by session progress/phase
  - [ ] Implement method: `requests_by_source` - count requests by widget location
  - [ ] Implement method: `resolution_rate` - percentage of resolved vs. unresolved
  - [ ] Add GraphQL query: `supportAnalytics: SupportAnalyticsType` (admin only)
  - [ ] Create `Types::SupportAnalyticsType` with analytics fields

- [ ] Task 6: Add client-side support tracking (AC: #2 - capture source)
  - [ ] When Intercom widget opened, pass `source` custom attribute (e.g., "insurance-verification", "session-recovery")
  - [ ] Use Intercom `update` method to set custom attributes before opening messenger
  - [ ] Document source values for consistency across frontend

- [ ] Task 7: Testing (all ACs)
  - [ ] Model specs: validate associations, required fields
  - [ ] Webhook controller specs: verify event handling, security, edge cases
  - [ ] GraphQL specs: test supportRequests query with authorization
  - [ ] Analytics service specs: test grouping and calculations
  - [ ] Integration test: simulate Intercom webhook → verify SupportRequest created and session flagged

## Dev Notes

### Architecture Context

- **Model Pattern**: Follow existing Rails model patterns (UUID primary keys, timestamps, foreign keys)
- **Webhook Security**: Verify Intercom webhook signatures using HMAC (similar to how Stripe webhooks are verified)
- **GraphQL Authorization**: Use Pundit policies for `SupportRequest` access control
- **Analytics**: Store source values as enum or string; define standard source locations in config

### Project Structure Notes

**New Files:**
- `app/models/support_request.rb` - ActiveRecord model
- `db/migrate/YYYYMMDDHHMMSS_create_support_requests.rb` - Migration
- `db/migrate/YYYYMMDDHHMMSS_add_contacted_support_to_onboarding_sessions.rb` - Migration
- `app/controllers/webhooks/intercom_controller.rb` - Webhook handler
- `app/services/analytics/support_analytics_service.rb` - Analytics service
- `app/graphql/types/support_request_type.rb` - GraphQL type
- `app/graphql/types/support_analytics_type.rb` - Analytics GraphQL type
- `app/policies/support_request_policy.rb` - Authorization policy
- `spec/models/support_request_spec.rb` - Model tests
- `spec/controllers/webhooks/intercom_controller_spec.rb` - Webhook tests
- `spec/services/analytics/support_analytics_service_spec.rb` - Analytics tests

**Modified Files:**
- `config/routes.rb` - Add webhook route
- `app/graphql/types/query_type.rb` - Add supportRequests and supportAnalytics queries
- `app/models/onboarding_session.rb` - Add has_many :support_requests association

### Technical Implementation Details

**SupportRequest Schema:**
```ruby
create_table :support_requests, id: :uuid do |t|
  t.references :onboarding_session, type: :uuid, foreign_key: true, null: false
  t.string :intercom_conversation_id
  t.string :source, null: false  # e.g., "insurance-step", "ai-chat", "session-recovery"
  t.boolean :resolved, default: false
  t.timestamps
end
```

**Intercom Webhook Events:**
- `conversation.user.created` - Parent initiates chat
- `conversation.user.replied` - Parent replies (optional tracking)
- `conversation.admin.closed` - Support agent closes conversation (mark resolved)

**Standard Source Values** (define in config):
- `welcome-screen`
- `ai-intake`
- `insurance-verification`
- `session-recovery`
- `assessment`
- `error-state`

**Webhook Security:**
```ruby
# Verify HMAC signature from Intercom
def verify_signature
  signature = request.headers['X-Hub-Signature']
  body = request.raw_post
  expected = OpenSSL::HMAC.hexdigest('sha1', ENV['INTERCOM_WEBHOOK_SECRET'], body)
  halt 401 unless Rack::Utils.secure_compare(signature, "sha1=#{expected}")
end
```

**Analytics Queries:**
- Group by `session.progress['currentStep']` to identify which onboarding phases trigger most support requests
- Track resolution time: `resolved_at - created_at`
- Identify sessions with multiple support requests (may indicate UX issues)

### References

- [Source: docs/epics.md#Story-7.3-Support-Request-Tracking] - Epic requirements
- [Source: docs/architecture.md#Project-Structure] - Rails patterns and conventions
- [Source: docs/architecture.md#Security-Architecture] - Webhook security patterns
- [Source: docs/sprint-artifacts/stories/7-2-session-context-passing.md] - Prerequisite story (once created)
- Intercom Webhook Documentation: https://developers.intercom.com/building-apps/docs/setting-up-webhooks

### Testing Strategy

**Model Tests:**
- Validate presence of required fields
- Test associations (belongs_to session)
- Test default values (resolved: false)

**Controller Tests:**
- Verify signature validation
- Test each webhook event type
- Test error handling (missing session_id, invalid payload)
- Test idempotency (duplicate webhooks)

**GraphQL Tests:**
- Test supportRequests query returns correct data
- Test authorization (only session owner or admin can query)
- Test empty results when no support requests exist

**Integration Tests:**
- Simulate full webhook flow: POST webhook → verify SupportRequest created → verify session.contacted_support updated
- Test analytics queries with fixture data

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context XML will be added here by context workflow -->

### Agent Model Used

<!-- Will be filled during development -->

### Debug Log References

<!-- Will be added during development -->

### Completion Notes List

<!-- Will be added during development -->

### File List

<!-- Will be added during development -->
