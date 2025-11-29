# Epic Technical Specification: Session Lifecycle & Authentication

Date: 2025-11-29
Author: BMad
Epic ID: 2
Status: Draft

---

## Overview

Epic 2 establishes the foundational session management and authentication infrastructure for the Daybreak Health onboarding system. This epic enables parents to start anonymous onboarding sessions, save progress automatically, resume from any device, and manage session lifecycle (expiration, abandonment). It also implements JWT-based authentication and role-based access control (RBAC) required for HIPAA compliance.

This epic directly impacts user experience by eliminating friction—parents can pause onboarding and return later without losing progress, even from a different device. The authentication foundation ensures all subsequent features operate within a secure, auditable framework.

**FRs Covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR43, FR47

## Objectives and Scope

### In Scope

- Anonymous session creation with CUID identifiers
- JWT token issuance and validation (anonymous + authenticated)
- Session progress persistence with Redis caching and DB write-through
- Session state machine (STARTED → IN_PROGRESS → ... → SUBMITTED/ABANDONED/EXPIRED)
- Session recovery via magic link email
- Session expiration with configurable TTL and cleanup jobs
- Explicit session abandonment with audit trail
- PHI field encryption using Rails 7 encryption
- Role-based access control via Pundit policies
- Rate limiting for anonymous vs authenticated users
- Comprehensive audit logging for all session operations

### Out of Scope

- Admin user management (Epic 7)
- OAuth/SSO integration for admin users (Epic 7)
- Full notification system (Epic 6) - only recovery email in scope
- Conversational AI integration (Epic 3)
- Insurance or assessment data (Epics 4, 5)

## System Architecture Alignment

This epic aligns with the Architecture document's session management patterns:

| Component | Architecture Location | Purpose |
|-----------|----------------------|---------|
| Session mutations | `app/graphql/mutations/sessions/` | Create, update, abandon sessions |
| Session model | `app/models/onboarding_session.rb` | State machine, validations |
| JWT service | `app/services/auth/jwt_service.rb` | Token encode/decode |
| Token service | `app/services/auth/token_service.rb` | Refresh tokens, recovery tokens |
| Pundit policies | `app/policies/` | RBAC enforcement |
| Encryptable concern | `app/models/concerns/encryptable.rb` | PHI encryption |
| Auditable concern | `app/models/concerns/auditable.rb` | Automatic audit logging |
| Cleanup job | `app/jobs/session_cleanup_job.rb` | Expire inactive sessions |
| Redis cache | `Rails.cache` | Session state caching |

**Key Architectural Constraints:**
- All PHI must use Rails 7 `encrypts` with `Encryptable` concern
- JWT tokens use HS256 algorithm with `Rails.application.credentials.jwt_secret!`
- State transitions validated in model layer
- Audit logs created for all state changes
- Redis used for session progress caching (1-hour TTL, write-through to DB)

[Source: docs/architecture.md#Project-Structure]
[Source: docs/architecture.md#Implementation-Patterns]

## Detailed Design

### Services and Modules

| Service | Responsibility | Inputs | Outputs |
|---------|---------------|--------|---------|
| `Auth::JwtService` | JWT encode/decode | Payload hash, expiration | JWT string or decoded hash |
| `Auth::TokenService` | Refresh & recovery tokens | Session ID, token type | Token string, validates tokens |
| `Sessions::ProgressService` | Progress merge & validation | Session, progress JSON | Updated progress |
| `Sessions::StateMachine` | Validate state transitions | Current state, target state | Boolean + errors |
| `Sessions::RecoveryService` | Magic link generation | Session, email | Recovery URL |
| `Sessions::CleanupService` | Expire inactive sessions | - | Count of expired sessions |

### Data Models and Contracts

**OnboardingSession Model:**
```ruby
class OnboardingSession < ApplicationRecord
  include Auditable

  enum :status, {
    started: 0,
    in_progress: 1,
    insurance_pending: 2,
    assessment_complete: 3,
    submitted: 4,
    abandoned: 5,
    expired: 6
  }

  # Associations
  has_one :parent, dependent: :destroy
  has_one :child, dependent: :destroy
  has_one :insurance, dependent: :destroy
  has_one :assessment, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :audit_logs, dependent: :nullify

  # Validations
  validates :expires_at, presence: true
  validates :status, presence: true

  # Scopes
  scope :active, -> { where.not(status: [:abandoned, :expired, :submitted]) }
  scope :expiring_soon, -> { active.where(expires_at: ..1.hour.from_now) }
  scope :expired_pending, -> { active.where(expires_at: ...Time.current) }
end
```

**RefreshToken Model (new):**
```ruby
class RefreshToken < ApplicationRecord
  belongs_to :onboarding_session

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :device_fingerprint, presence: true

  scope :valid, -> { where(revoked_at: nil).where('expires_at > ?', Time.current) }
end
```

**Migration for refresh_tokens:**
```ruby
create_table :refresh_tokens, id: :uuid do |t|
  t.references :onboarding_session, type: :uuid, foreign_key: true, null: false
  t.string :token, null: false, index: { unique: true }
  t.string :device_fingerprint
  t.datetime :expires_at, null: false
  t.datetime :revoked_at
  t.timestamps
end
```

**Progress JSON Structure:**
```json
{
  "currentStep": "parent_info",
  "completedSteps": ["welcome"],
  "intake": {
    "parentInfo": { "status": "complete" },
    "childInfo": { "status": "pending" }
  },
  "insurance": {},
  "assessment": {}
}
```

### APIs and Interfaces

**GraphQL Mutations:**

```graphql
# Create anonymous session
mutation CreateSession($input: CreateSessionInput) {
  createSession(input: $input) {
    session {
      id
      status
      createdAt
      expiresAt
    }
    token
    refreshToken
  }
}

input CreateSessionInput {
  referralSource: String
}

# Update session progress
mutation UpdateSessionProgress($sessionId: ID!, $progress: JSON!) {
  updateSessionProgress(sessionId: $sessionId, progress: $progress) {
    session {
      id
      status
      progress
      updatedAt
      expiresAt
    }
  }
}

# Request session recovery (magic link)
mutation RequestSessionRecovery($email: String!) {
  requestSessionRecovery(email: $email) {
    success
    message
  }
}

# Recover session with token
mutation RecoverSession($token: String!) {
  recoverSession(token: $token) {
    session {
      id
      status
      progress
    }
    token
    refreshToken
  }
}

# Abandon session
mutation AbandonSession($sessionId: ID!) {
  abandonSession(sessionId: $sessionId) {
    session {
      id
      status
    }
  }
}

# Refresh access token
mutation RefreshToken($refreshToken: String!) {
  refreshToken(refreshToken: $refreshToken) {
    token
    refreshToken
  }
}
```

**GraphQL Queries:**

```graphql
query GetSession($id: ID!) {
  session(id: $id) {
    id
    status
    progress
    createdAt
    updatedAt
    expiresAt
  }
}
```

**GraphQL Subscriptions:**

```graphql
subscription SessionUpdated($sessionId: ID!) {
  sessionUpdated(sessionId: $sessionId) {
    session {
      id
      status
      progress
      updatedAt
    }
  }
}
```

**Error Codes:**

| Code | HTTP | Scenario |
|------|------|----------|
| `UNAUTHENTICATED` | 401 | Invalid/missing JWT |
| `SESSION_EXPIRED` | 401 | Session past expiresAt |
| `SESSION_ABANDONED` | 400 | Cannot update abandoned session |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `RATE_LIMITED` | 429 | Too many requests |
| `VALIDATION_ERROR` | 400 | Invalid input |

### Workflows and Sequencing

**Session Creation Flow:**
```
Parent → createSession mutation
       → Generate UUID with 'sess_' prefix
       → Create OnboardingSession (status: started, expiresAt: +24h)
       → Generate JWT (1h expiry, payload: { session_id, role: 'anonymous' })
       → Generate refresh token (7d expiry, store in DB)
       → Create AuditLog (action: SESSION_CREATED)
       → Return { session, token, refreshToken }
```

**Progress Update Flow:**
```
Parent → updateSessionProgress mutation
       → Validate JWT, extract session_id
       → Load session from cache (Redis) or DB
       → Validate session is active (not abandoned/expired)
       → Deep merge new progress with existing
       → Transition status: started → in_progress (if first update)
       → Extend expiresAt by 1 hour
       → Write to Redis cache (1h TTL)
       → Async write to DB (write-through)
       → Create AuditLog (action: PROGRESS_UPDATED)
       → Broadcast via sessionUpdated subscription
       → Return updated session
```

**Session Recovery Flow:**
```
Parent → requestSessionRecovery mutation
       → Find session by parent email
       → Validate session is active
       → Check rate limit (3 requests/hour/email)
       → Generate recovery token (store in Redis, 15min TTL)
       → Send email with magic link
       → Create AuditLog (action: RECOVERY_REQUESTED)
       → Return success

Parent clicks link → recoverSession mutation
       → Validate recovery token exists in Redis
       → Delete token from Redis (one-time use)
       → Load session
       → Generate new JWT
       → Generate new refresh token
       → Create AuditLog (action: SESSION_RECOVERED, details: { device, ip })
       → Return { session, token, refreshToken }
```

**Session Expiration Flow (Background Job):**
```
SessionCleanupJob (runs every 15 min via Sidekiq-cron)
       → Query: OnboardingSession.expired_pending
       → For each session:
         → Update status to 'expired'
         → Create AuditLog (action: SESSION_EXPIRED)
       → Log count of expired sessions
```

**State Transition Rules:**
```
started → in_progress (on first progress update)
started → abandoned (explicit)
started → expired (timeout)

in_progress → insurance_pending (on insurance start)
in_progress → abandoned (explicit)
in_progress → expired (timeout)

insurance_pending → assessment_complete (on assessment complete)
insurance_pending → abandoned (explicit)
insurance_pending → expired (timeout)

assessment_complete → submitted (on final submit)
assessment_complete → abandoned (explicit)
assessment_complete → expired (timeout)

abandoned → (terminal, no transitions)
expired → (terminal, no transitions)
submitted → (terminal, no transitions)
```

## Non-Functional Requirements

### Performance

| Metric | Target | Implementation |
|--------|--------|----------------|
| createSession latency | p95 < 200ms | Minimal DB writes, async audit |
| updateSessionProgress latency | p95 < 100ms | Redis cache first |
| Session query latency | p95 < 50ms | Redis cache hit |
| Token validation | p95 < 10ms | In-memory decode |
| Cleanup job duration | < 5 min | Batch processing, 1000/batch |

**Caching Strategy:**
- Session progress cached in Redis with 1-hour TTL
- Write-through: update cache → async write to DB
- Cache key format: `session:progress:{session_id}`
- Invalidate on status change to terminal state

[Source: docs/prd.md#Performance]

### Security

| Requirement | Implementation |
|-------------|----------------|
| JWT algorithm | HS256 (upgrade to RS256 in Story 2.6) |
| Access token expiry | 1 hour (configurable via `SESSION_TOKEN_EXPIRATION_HOURS`) |
| Refresh token expiry | 7 days |
| Recovery token expiry | 15 minutes |
| Rate limiting (anonymous) | 100 requests/minute |
| Rate limiting (authenticated) | 1000 requests/minute |
| PHI encryption | Rails 7 encryption (AES-256-GCM) |
| Audit logging | All session operations |

**Roles:**
- `anonymous`: Create session, update own session
- `parent`: Read/write own session, request recovery
- `coordinator`: Read assigned sessions
- `admin`: Read all sessions, update status
- `system`: Background jobs, integrations

[Source: docs/prd.md#Security]
[Source: docs/architecture.md#Security-Architecture]

### Reliability/Availability

| Requirement | Implementation |
|-------------|----------------|
| Session data durability | Write-through cache to PostgreSQL |
| Redis failure handling | Fallback to direct DB reads |
| Background job retry | Exponential backoff, max 3 attempts |
| Graceful degradation | Session operations work without subscriptions |

### Observability

| Signal | Type | Purpose |
|--------|------|---------|
| `session.created` | Counter | Track new sessions |
| `session.status_changed` | Counter (by status) | Funnel analysis |
| `session.expired` | Counter | Monitor abandonment |
| `session.recovered` | Counter | Multi-device usage |
| `auth.token_issued` | Counter | Auth activity |
| `auth.token_refresh` | Counter | Session longevity |
| `cache.hit_rate` | Gauge | Cache effectiveness |
| `cleanup_job.duration` | Histogram | Job performance |

**Structured Logging:**
```ruby
Rails.logger.info("Session created", {
  session_id: session.id,
  referral_source: session.referral_source,
  # Never log PHI
})
```

## Dependencies and Integrations

### Gem Dependencies

| Gem | Version | Purpose |
|-----|---------|---------|
| `jwt` | ~> 2.7 | JWT encode/decode |
| `bcrypt` | ~> 3.1 | Token hashing |
| `pundit` | ~> 2.3 | Authorization policies |
| `redis` | ~> 5.0 | Caching backend |
| `sidekiq` | ~> 7.0 | Background jobs |
| `sidekiq-cron` | ~> 1.9 | Scheduled jobs |

### External Dependencies

| Service | Purpose | Epic 2 Usage |
|---------|---------|--------------|
| Redis | Session cache, recovery tokens | Required |
| PostgreSQL | Session persistence | Required |
| AWS SES | Recovery email delivery | Story 2.3 only |

### Internal Dependencies

| Dependency | Story | Required By |
|------------|-------|-------------|
| Epic 1 complete | All Epic 1 stories | All Epic 2 stories |
| Story 2.1 | - | Stories 2.2-2.6 |
| Story 2.2 | State machine | Stories 2.3, 2.4, 2.5 |
| Email service stub | Story 6.1 (can mock) | Story 2.3 |

## Acceptance Criteria (Authoritative)

### Story 2.1: Create Anonymous Session
1. `createSession` mutation creates new OnboardingSession with status `STARTED`
2. Session ID is a CUID format (e.g., `sess_clx123...`)
3. Anonymous JWT token issued with session ID as subject
4. Token expires in 1 hour (configurable)
5. Session `expiresAt` set to 24 hours from creation
6. `progress` JSON initialized as empty object `{}`
7. Response includes: `{ session: { id, status, createdAt }, token }`
8. Session can be queried with the returned token
9. Audit log entry created: `action: SESSION_CREATED`

### Story 2.2: Session Progress & State Management
1. `updateSessionProgress` mutation updates `progress` JSON field
2. Session status transitions: STARTED → IN_PROGRESS (on first progress update)
3. `updatedAt` timestamp refreshed
4. Session `expiresAt` extended by 1 hour on activity
5. Progress is merged (not replaced) with existing data
6. GraphQL subscription `sessionUpdated` fires with new state
7. Progress persists across page refreshes
8. Status transitions follow valid state machine (no backward transitions except to ABANDONED)

### Story 2.3: Session Recovery & Multi-Device Support
1. `requestSessionRecovery` mutation sends magic link to email
2. Magic link contains time-limited token (15 minutes)
3. `sessionByRecoveryToken` query validates token and returns session
4. New JWT issued for recovered session
5. Previous tokens NOT invalidated (allow multiple devices)
6. Recovery link works only once
7. Parent can continue from exact progress point
8. Audit log: `action: SESSION_RECOVERED, details: { device, ip }`

### Story 2.4: Session Expiration & Cleanup
1. Sessions with `expiresAt` in the past marked as `EXPIRED`
2. Expired sessions retained in database for 90 days (compliance)
3. Associated data (messages, progress) retained with session
4. No new activity allowed on expired sessions
5. Cleanup job runs every 15 minutes via scheduled task
6. Attempting to update expired session returns `SESSION_EXPIRED` error
7. Audit log: `action: SESSION_EXPIRED`

### Story 2.5: Explicit Session Abandonment
1. Confirmation required before abandonment (client-side)
2. `abandonSession` mutation sets status to `ABANDONED`
3. Session data retained per policy (same as expiration)
4. Parent can create new session immediately
5. Abandoned session cannot be resumed
6. Response confirms abandonment with session ID
7. Audit log: `action: SESSION_ABANDONED, details: { previousStatus }`

### Story 2.6: Authentication & Authorization Foundation
1. JWT validation using RS256 algorithm
2. Token refresh mechanism with 7-day refresh tokens
3. Roles: `anonymous`, `parent`, `coordinator`, `admin`, `system`
4. Pundit policies enforce permission checks
5. Rate limiting: 100 requests/minute for anonymous, 1000 for authenticated
6. All PHI fields encrypted at rest using AES-256-GCM
7. Encryption key managed via Rails credentials
8. Unauthorized requests return `UNAUTHENTICATED` (401)
9. Forbidden requests return `FORBIDDEN` (403)
10. Audit log captures all authentication events

## Traceability Mapping

| AC | Spec Section | Component(s) | Test Idea |
|----|--------------|--------------|-----------|
| 2.1.1 | APIs/CreateSession | `mutations/sessions/create_session.rb` | Verify status=started |
| 2.1.2 | Data Models | `OnboardingSession` | Verify ID format matches regex |
| 2.1.3 | Services | `Auth::JwtService` | Decode token, verify payload |
| 2.1.4 | Services | `Auth::JwtService` | Check exp claim |
| 2.1.5 | APIs/CreateSession | `OnboardingSession` | Verify expiresAt = now + 24h |
| 2.1.6 | Data Models | `OnboardingSession` | Verify progress = {} |
| 2.1.7 | APIs/CreateSession | `mutations/sessions/` | Verify response shape |
| 2.1.8 | APIs/GetSession | `types/query_type.rb` | Query with token, verify access |
| 2.1.9 | Workflows | `AuditLog` | Verify audit entry exists |
| 2.2.1 | APIs/UpdateProgress | `mutations/sessions/update_progress.rb` | Before/after progress comparison |
| 2.2.2 | Workflows | `Sessions::StateMachine` | Verify transition on first update |
| 2.2.3 | Data Models | `OnboardingSession` | Check updatedAt changed |
| 2.2.4 | APIs/UpdateProgress | `OnboardingSession` | Verify expiresAt extended |
| 2.2.5 | Services | `Sessions::ProgressService` | Merge test with nested JSON |
| 2.2.6 | APIs/Subscriptions | `subscriptions/session_updated.rb` | WebSocket receives update |
| 2.2.7 | Workflows | Redis cache | Reload page, verify progress |
| 2.2.8 | Services | `Sessions::StateMachine` | Attempt invalid transition |
| 2.3.1 | APIs/RequestRecovery | `Sessions::RecoveryService` | Verify email sent |
| 2.3.2 | Workflows | Redis | Check TTL = 15 min |
| 2.3.3 | APIs/RecoverSession | `mutations/sessions/` | Validate and return session |
| 2.3.4 | Services | `Auth::JwtService` | Verify new token issued |
| 2.3.5 | Workflows | Multiple tokens | Both tokens work |
| 2.3.6 | Workflows | Redis | Second use fails |
| 2.3.7 | Workflows | Progress | Compare before/after recovery |
| 2.3.8 | Workflows | `AuditLog` | Verify details include device/ip |
| 2.4.1 | Workflows | `SessionCleanupJob` | Verify status = expired |
| 2.4.2 | NFR/Security | DB query | Session exists after 90 days |
| 2.4.3 | Data Models | Associations | Verify related data intact |
| 2.4.4 | APIs | All mutations | Verify rejection of expired session |
| 2.4.5 | Workflows | Sidekiq-cron | Verify job runs on schedule |
| 2.4.6 | Error handling | GraphQL errors | Verify error code = SESSION_EXPIRED |
| 2.4.7 | Workflows | `AuditLog` | Verify audit entry |
| 2.5.1 | APIs | Client-side | (Frontend responsibility) |
| 2.5.2 | APIs/AbandonSession | `mutations/sessions/abandon_session.rb` | Verify status = abandoned |
| 2.5.3 | NFR/Reliability | DB | Data exists after abandon |
| 2.5.4 | APIs/CreateSession | Sequential calls | New session created |
| 2.5.5 | APIs | All mutations | Verify rejection of abandoned session |
| 2.5.6 | APIs/AbandonSession | Response | Verify session ID in response |
| 2.5.7 | Workflows | `AuditLog` | Verify previousStatus in details |
| 2.6.1 | Security | `Auth::JwtService` | Verify RS256 algorithm |
| 2.6.2 | Services | `Auth::TokenService` | Refresh flow works |
| 2.6.3 | Security | Pundit policies | Role assignment correct |
| 2.6.4 | Security | `ApplicationPolicy` | Policy enforcement test |
| 2.6.5 | NFR/Security | Rack::Attack | Rate limit triggered |
| 2.6.6 | Data Models | `Encryptable` | Encrypted in DB, decrypted in app |
| 2.6.7 | Security | Credentials | Key management test |
| 2.6.8 | Error handling | Auth errors | 401 response format |
| 2.6.9 | Error handling | Auth errors | 403 response format |
| 2.6.10 | Workflows | `AuditLog` | Auth events logged |

## Risks, Assumptions, Open Questions

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Redis unavailability | Low | Medium | Fallback to direct DB reads |
| Token theft | Low | High | Short expiry, refresh rotation |
| Recovery email abuse | Medium | Low | Rate limiting (3/hour/email) |
| State machine bugs | Medium | Medium | Comprehensive state transition tests |

### Assumptions

- Epic 1 foundation stories are complete and tested
- AWS SES is available for recovery emails (can mock for Story 2.3 if not)
- Team is familiar with Pundit authorization patterns
- Redis is deployed and accessible in all environments

### Open Questions

1. **Q:** Should RS256 be used from Story 2.1 or migrate in Story 2.6?
   **A:** Start with HS256 in Story 2.1, migrate to RS256 in Story 2.6 to align with Architecture doc's final state.

2. **Q:** What happens to refresh tokens when session is abandoned/expired?
   **A:** Mark all refresh tokens as revoked when session reaches terminal state.

3. **Q:** Should recovery email be mandatory for session recovery, or allow phone-based recovery?
   **A:** MVP is email-only per PRD. Phone recovery is post-MVP.

## Test Strategy Summary

### Unit Tests

- `Auth::JwtService` - encode/decode, expiration, invalid tokens
- `Auth::TokenService` - refresh token generation, validation, revocation
- `Sessions::ProgressService` - merge logic, validation
- `Sessions::StateMachine` - all valid transitions, all invalid transitions
- `Sessions::RecoveryService` - token generation, rate limiting
- All Pundit policies - role-based access scenarios

### Integration Tests

- Full session lifecycle: create → update → abandon
- Full session lifecycle: create → update → expire
- Recovery flow: request → email sent → recover
- Refresh token flow: access expired → refresh → new access
- Subscription delivery: update progress → subscription receives
- Rate limiting: exceed limit → 429 response

### Edge Cases

- Concurrent progress updates (last-write-wins)
- Recovery token reuse attempt
- Expired session update attempt
- Abandoned session update attempt
- Invalid state transitions
- Token refresh with revoked refresh token
- Multiple device recovery tokens

### Security Tests

- JWT tampering detection
- Token reuse after revocation
- RBAC enforcement across all mutations
- PHI field encryption verification (DB inspection)
- Audit log completeness

[Source: docs/architecture.md#Project-Structure]
[Source: docs/prd.md#Functional-Requirements]
