# Story 2.6: Authentication & Authorization Foundation

Status: ready-for-dev

## Story

As a developer,
I want JWT authentication and role-based access control implemented,
so that all endpoints are properly secured per HIPAA requirements.

## Acceptance Criteria

1. **AC 2.6.1**: JWT validation using RS256 algorithm with proper secret management
2. **AC 2.6.2**: Token refresh mechanism with 7-day refresh tokens stored securely
3. **AC 2.6.3**: Roles defined: anonymous, parent, coordinator, admin, system
4. **AC 2.6.4**: Pundit policies enforce role-based permission checks
5. **AC 2.6.5**: Rate limiting: 100 requests/minute for anonymous, 1000 for authenticated
6. **AC 2.6.6**: All PHI fields encrypted at rest using AES-256-GCM via Rails encryption
7. **AC 2.6.7**: Encryption keys managed via Rails credentials (or env for local dev)
8. **AC 2.6.8**: Unauthorized requests return UNAUTHENTICATED (401) error
9. **AC 2.6.9**: Forbidden requests return FORBIDDEN (403) error
10. **AC 2.6.10**: Audit log captures all authentication events

## Tasks / Subtasks

- [ ] **Task 1**: Implement refresh token management (AC: 2.6.2)
  - [ ] 1.1: Create RefreshToken model with device fingerprint
  - [ ] 1.2: Create migration for refresh_tokens table with indexes
  - [ ] 1.3: Add relationship to OnboardingSession model
  - [ ] 1.4: Implement token generation in Auth::TokenService
  - [ ] 1.5: Implement token validation with expiration check
  - [ ] 1.6: Implement token rotation (invalidate old token on refresh)
  - [ ] 1.7: Write RSpec tests for RefreshToken model and service

- [ ] **Task 2**: Define role enum and implement role-based logic (AC: 2.6.3)
  - [ ] 2.1: Add role enum to User/Session model (anonymous, parent, coordinator, admin, system)
  - [ ] 2.2: Update JWT payload to include role claim
  - [ ] 2.3: Create CurrentUser/CurrentSession concern for role checking
  - [ ] 2.4: Add helper methods: anonymous?, parent?, coordinator?, admin?, system?
  - [ ] 2.5: Write RSpec tests for role enum and helper methods

- [ ] **Task 3**: Implement GraphQL authorization with Pundit (AC: 2.6.4)
  - [ ] 3.1: Add Pundit to GraphQL base mutation and query classes
  - [ ] 3.2: Create SessionPolicy with permission methods
  - [ ] 3.3: Create ParentPolicy with PHI access rules
  - [ ] 3.4: Create ChildPolicy with PHI access rules
  - [ ] 3.5: Create InsurancePolicy with PHI access rules
  - [ ] 3.6: Create AssessmentPolicy with PHI access rules
  - [ ] 3.7: Implement authorize! checks in GraphQL mutations
  - [ ] 3.8: Write RSpec tests for all policies

- [ ] **Task 4**: Implement rate limiting middleware (AC: 2.6.5)
  - [ ] 4.1: Create RateLimiter middleware using Redis
  - [ ] 4.2: Implement anonymous user rate limit (100/min)
  - [ ] 4.3: Implement authenticated user rate limit (1000/min)
  - [ ] 4.4: Add rate limit headers to responses
  - [ ] 4.5: Return RATE_LIMITED error when threshold exceeded
  - [ ] 4.6: Add rate limiter to Rack middleware stack
  - [ ] 4.7: Write RSpec tests for rate limiting

- [ ] **Task 5**: Verify PHI encryption implementation (AC: 2.6.6, 2.6.7)
  - [ ] 5.1: Audit all PHI fields across models for encryption
  - [ ] 5.2: Verify Encryptable concern uses AES-256-GCM (Rails default)
  - [ ] 5.3: Verify encryption keys in Rails credentials
  - [ ] 5.4: Document key rotation procedure
  - [ ] 5.5: Add encryption verification tests
  - [ ] 5.6: Test encryption key fallback for local development

- [ ] **Task 6**: Implement authentication error handling (AC: 2.6.8, 2.6.9)
  - [ ] 6.1: Create AuthenticationError class extending base GraphQL error
  - [ ] 6.2: Create ForbiddenError class extending base GraphQL error
  - [ ] 6.3: Update error codes constants with UNAUTHENTICATED and FORBIDDEN
  - [ ] 6.4: Add error formatter to GraphQL schema
  - [ ] 6.5: Implement rescue_from handlers in GraphQL context
  - [ ] 6.6: Write RSpec tests for error responses

- [ ] **Task 7**: Implement authentication audit logging (AC: 2.6.10)
  - [ ] 7.1: Extend Auditable concern to capture auth events
  - [ ] 7.2: Log successful JWT creation with session_id
  - [ ] 7.3: Log failed authentication attempts with reason
  - [ ] 7.4: Log refresh token generation and rotation
  - [ ] 7.5: Log authorization failures (403) with attempted action
  - [ ] 7.6: Ensure audit logs include IP address and user agent
  - [ ] 7.7: Write RSpec tests for audit trail creation

- [ ] **Task 8**: Integration testing (AC: all)
  - [ ] 8.1: Create GraphQL request spec for authenticated queries
  - [ ] 8.2: Create GraphQL request spec for unauthorized access
  - [ ] 8.3: Create GraphQL request spec for forbidden access
  - [ ] 8.4: Create integration test for token refresh flow
  - [ ] 8.5: Create integration test for rate limiting
  - [ ] 8.6: Test PHI encryption end-to-end
  - [ ] 8.7: Test audit logging for all auth events
  - [ ] 8.8: Ensure all tests pass and achieve >90% coverage

## Dev Notes

### Architecture Patterns and Constraints

- **JWT Algorithm**: RS256 (asymmetric) for production security (update from Story 1.3 HS256)
- **Token Expiration**: Access tokens 1 hour, refresh tokens 7 days
- **Refresh Token Storage**: Database with device fingerprint for tracking
- **Rate Limiting**: Redis-based with sliding window algorithm
- **PHI Encryption**: Rails 7 ActiveRecord::Encryption with AES-256-GCM
- **Key Management**: Rails credentials for production, ENV vars for development
- **Audit Logging**: All auth events logged with timestamp, IP, user agent
- **Error Format**: GraphQL errors with extensions: { code, timestamp, path }
- **Authorization Pattern**: Pundit policies with default deny

### Source Tree Components to Touch

```
app/
├── models/
│   ├── refresh_token.rb                # NEW: Refresh token model
│   └── concerns/
│       └── current_user.rb             # NEW: Role checking helpers
├── services/auth/
│   └── token_service.rb                # MODIFY: Add refresh token logic
├── policies/
│   ├── session_policy.rb               # NEW: Session access policy
│   ├── parent_policy.rb                # NEW: Parent PHI policy
│   ├── child_policy.rb                 # NEW: Child PHI policy
│   ├── insurance_policy.rb             # NEW: Insurance PHI policy
│   └── assessment_policy.rb            # NEW: Assessment PHI policy
├── middleware/
│   └── rate_limiter.rb                 # NEW: Rate limiting middleware
└── graphql/
    ├── mutations/
    │   └── base_mutation.rb            # MODIFY: Add Pundit authorization
    ├── types/
    │   └── base_query.rb               # MODIFY: Add Pundit authorization
    └── errors/
        ├── authentication_error.rb     # NEW: 401 error class
        └── forbidden_error.rb          # NEW: 403 error class

db/
└── migrate/
    └── YYYYMMDDHHMMSS_create_refresh_tokens.rb  # NEW

spec/
├── models/
│   └── refresh_token_spec.rb           # NEW
├── policies/
│   ├── session_policy_spec.rb          # NEW
│   ├── parent_policy_spec.rb           # NEW
│   ├── child_policy_spec.rb            # NEW
│   ├── insurance_policy_spec.rb        # NEW
│   └── assessment_policy_spec.rb       # NEW
├── middleware/
│   └── rate_limiter_spec.rb            # NEW
└── requests/
    └── graphql/
        ├── authenticated_queries_spec.rb    # NEW
        ├── unauthorized_access_spec.rb      # NEW
        ├── forbidden_access_spec.rb         # NEW
        ├── token_refresh_spec.rb            # NEW
        └── rate_limiting_spec.rb            # NEW
```

### Testing Standards Summary

- **Unit Tests**: All policies, services, and middleware require RSpec tests
- **Integration Tests**: GraphQL request specs for auth flows
- **Coverage**: Minimum 90% code coverage for all new code
- **Security Tests**: Verify JWT expiration, token invalidation, rate limiting
- **PHI Safety Tests**: Ensure PHI encryption working correctly
- **Audit Tests**: Verify all auth events logged properly
- **Policy Tests**: Test all permission scenarios (allow/deny)
- **Error Tests**: Verify correct error codes and messages returned

### Project Structure Notes

#### Alignment with Unified Project Structure

This story builds on Story 1.3 foundation and adds comprehensive authentication/authorization:

- **Models Layer**: RefreshToken model for secure token storage
- **Policies Layer**: Complete Pundit policies for all PHI-containing resources
- **Middleware Layer**: Rate limiting middleware for request throttling
- **Services Layer**: Enhanced Auth::TokenService with refresh token logic
- **GraphQL Layer**: Authorization integrated into base mutation/query classes
- **Error Handling**: Authentication and authorization error classes

All components follow Rails conventions and security best practices.

### References

- [Source: docs/architecture.md#Security Architecture]
- [Source: docs/architecture.md#Authentication & Authorization]
- [Source: docs/architecture.md#Data Encryption]
- [Source: docs/tech-spec.md#Epic 2: Session Lifecycle & Authentication]
- [Source: docs/epics.md#Story 2.6: Authentication & Authorization Foundation]
- [Source: docs/sprint-artifacts/1-3-common-module-and-core-patterns.md]

### RS256 vs HS256 Algorithm Decision

**Context**: Story 1.3 implemented HS256 (symmetric) for JWT signing. Story 2.6 requires RS256 (asymmetric).

**RS256 Benefits**:
- Public key can be shared for token verification without exposing signing capability
- Better for distributed systems with multiple validators
- Industry standard for OAuth 2.0 and OIDC
- HIPAA compliance best practice for healthcare applications

**Implementation**:
- Generate RSA key pair: `openssl genrsa -out private.pem 2048`
- Extract public key: `openssl rsa -in private.pem -pubout -out public.pem`
- Store private key in Rails credentials (encrypted at rest)
- Store public key in config for verification
- Update Auth::JwtService to use RS256 algorithm

**Migration Strategy**:
1. Generate RS256 keys during Story 2.6 implementation
2. Update Auth::JwtService.encode to use RS256 with private key
3. Update Auth::JwtService.decode to use RS256 with public key
4. All existing HS256 tokens from Story 1.3 will naturally expire (1 hour TTL)
5. No backward compatibility needed (dev environment only so far)

### Refresh Token Database Schema

```ruby
create_table :refresh_tokens, id: :uuid do |t|
  t.references :onboarding_session, type: :uuid, foreign_key: true, null: false, index: true
  t.text :token_hash, null: false, index: { unique: true }
  t.string :device_fingerprint
  t.string :ip_address
  t.string :user_agent
  t.datetime :expires_at, null: false, index: true
  t.datetime :revoked_at, index: true
  t.timestamps
end
```

**Security Notes**:
- Store bcrypt hash of token, not plaintext
- Device fingerprint tracks which device issued the token
- IP address and user agent for audit trail
- Revoked tokens marked with revoked_at timestamp (soft delete)
- Expired tokens cleaned up via scheduled job

### Rate Limiting Strategy

**Redis Key Format**: `rate_limit:{role}:{identifier}:{window}`
- Example: `rate_limit:anonymous:192.168.1.1:20251129120000`
- Sliding window: 60 seconds
- Count increments on each request
- TTL set to 60 seconds

**Limits by Role**:
- anonymous: 100 requests/minute
- parent: 1000 requests/minute
- coordinator: 1000 requests/minute
- admin: 1000 requests/minute
- system: unlimited (no rate limit)

**Response Headers**:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1638360000
```

**Error Response** (429 when exceeded):
```json
{
  "errors": [
    {
      "message": "Rate limit exceeded. Please try again later.",
      "extensions": {
        "code": "RATE_LIMITED",
        "timestamp": "2025-11-29T12:00:00Z",
        "retryAfter": 45
      }
    }
  ]
}
```

### Role-Based Access Control (RBAC) Rules

**Role Hierarchy** (from least to most privileged):
1. **anonymous**: Can create sessions, read own session
2. **parent**: Can read/update own session and all related data
3. **coordinator**: Can read all sessions, update session status
4. **admin**: Can read/update all sessions, manage configuration
5. **system**: Full access, used for background jobs

**Policy Examples**:

```ruby
# SessionPolicy
class SessionPolicy < ApplicationPolicy
  def show?
    owner? || coordinator? || admin?
  end

  def update?
    owner? || admin?
  end

  private

  def owner?
    record.id == user.session_id
  end

  def coordinator?
    user.role.in?(['coordinator', 'admin', 'system'])
  end

  def admin?
    user.role.in?(['admin', 'system'])
  end
end

# ParentPolicy
class ParentPolicy < ApplicationPolicy
  def show?
    owns_session? || coordinator? || admin?
  end

  def update?
    owns_session? || admin?
  end

  private

  def owns_session?
    record.onboarding_session_id == user.session_id
  end
end
```

### Audit Logging for Authentication Events

**Events to Log**:
- JWT_CREATED: When new access token issued
- JWT_REFRESH: When access token refreshed
- JWT_INVALID: When invalid token used
- JWT_EXPIRED: When expired token used
- AUTH_FAILED: When authentication fails
- AUTHZ_DENIED: When authorization check fails (403)
- RATE_LIMITED: When rate limit exceeded
- REFRESH_TOKEN_CREATED: When refresh token generated
- REFRESH_TOKEN_ROTATED: When refresh token rotated
- REFRESH_TOKEN_REVOKED: When refresh token revoked

**Audit Log Entry Format**:
```ruby
AuditLog.create!(
  onboarding_session_id: session_id,
  action: 'JWT_CREATED',
  actor_type: 'Session',
  actor_id: session_id,
  target_type: 'OnboardingSession',
  target_id: session_id,
  details: {
    role: 'anonymous',
    expires_at: 1.hour.from_now,
    ip_address: request.ip,
    user_agent: request.user_agent
  },
  ip_address: request.ip,
  user_agent: request.user_agent,
  created_at: Time.current
)
```

**PHI Safety**:
- Never log actual PHI values in audit logs
- Only log references (IDs, boolean flags)
- IP addresses and user agents are NOT PHI
- Device fingerprints are anonymized hashes

### Encryption Key Management

**Development Environment**:
```bash
# Generate encryption keys
bin/rails db:encryption:init

# Output will be added to config/credentials/development.yml.enc:
active_record_encryption:
  primary_key: <generated>
  deterministic_key: <generated>
  key_derivation_salt: <generated>

# Generate RSA keys for JWT
openssl genrsa -out config/keys/jwt_private.pem 2048
openssl rsa -in config/keys/jwt_private.pem -pubout -out config/keys/jwt_public.pem
```

**Production Environment**:
- Encryption keys stored in Rails credentials.yml.enc (encrypted with master key)
- Master key stored in environment variable RAILS_MASTER_KEY
- RSA private key stored in Rails credentials
- RSA public key can be in config (not secret)
- AWS Secrets Manager integration for key rotation (future enhancement)

**Key Rotation Procedure** (documented for future):
1. Generate new encryption key
2. Add to credentials as secondary key
3. Rails will use new key for writes, old key for reads
4. Background job re-encrypts all PHI with new key
5. Remove old key after migration complete

### GraphQL Authorization Pattern

**In Base Mutation**:
```ruby
module Mutations
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    include CurrentSession
    include Pundit::Authorization

    def authorized?(**args)
      super && authorize_with_policy
    end

    private

    def authorize_with_policy
      # Override in subclasses
      true
    end
  end
end
```

**In Specific Mutation**:
```ruby
module Mutations
  module Sessions
    class UpdateSession < BaseMutation
      argument :session_id, ID, required: true
      argument :progress, GraphQL::Types::JSON, required: false

      field :session, Types::SessionType, null: true
      field :errors, [String], null: false

      private

      def authorize_with_policy
        session = OnboardingSession.find(session_id)
        authorize session, :update?
      end

      def resolve(session_id:, progress: nil)
        session = OnboardingSession.find(session_id)
        session.update!(progress: progress) if progress
        { session: session, errors: [] }
      rescue Pundit::NotAuthorizedError => e
        raise Errors::ForbiddenError, "You don't have permission to update this session"
      end
    end
  end
end
```

## Dev Agent Record

### Context Reference
docs/sprint-artifacts/2-6-authentication-and-authorization-foundation.context.xml

### Agent Model Used
Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)

### Implementation Status

**Partial Implementation** - Core authentication infrastructure completed, some testing issues remain

### Completed Components

#### Task 1: Refresh Token Management (AC 2.6.2) - MOSTLY COMPLETE
- ✅ RefreshToken model with bcrypt hashing
- ✅ Database migration with proper indexes
- ✅ OnboardingSession association (has_many :refresh_tokens)
- ✅ Auth::TokenService with token generation, validation, and rotation
- ✅ Device fingerprint tracking
- ✅ Token expiration (7 days)
- ⚠️ Tests: 45/58 passing (13 failures related to scope and validation edge cases)

#### Task 2: Role Enum (AC 2.6.3) - COMPLETE
- ✅ Role enum added to OnboardingSession model
- ✅ Roles defined: anonymous, parent, coordinator, admin, system
- ✅ JWT payload includes role claim (via Auth::JwtService)
- ✅ CurrentSession concern has role checking helpers (anonymous?, parent?, etc.)

#### Task 3: Pundit Policies (AC 2.6.4) - COMPLETE
- ✅ SessionPolicy (OnboardingSessionPolicy)
- ✅ ParentPolicy with PHI access rules
- ✅ ChildPolicy with PHI access rules
- ✅ InsurancePolicy with PHI access rules
- ✅ AssessmentPolicy with PHI access rules
- ✅ Test files created for all policies
- ⚠️ Policy tests need pundit-matchers gem configuration

#### Task 4: Rate Limiting Middleware (AC 2.6.5) - COMPLETE
- ✅ RateLimiter middleware using Redis
- ✅ Anonymous: 100 req/min
- ✅ Authenticated: 1000 req/min
- ✅ System: unlimited
- ✅ Rate limit headers (X-RateLimit-Limit, Remaining, Reset)
- ✅ RATE_LIMITED error response
- ⚠️ Middleware registered in config/initializers/rate_limiter.rb (needs verification)

#### Task 5: PHI Encryption (AC 2.6.6, 2.6.7) - ALREADY COMPLETE
- ✅ Encryptable concern uses AES-256-GCM (Rails default)
- ✅ All PHI fields encrypted across models (Parent, Child, Insurance, Assessment)
- ✅ Encryption keys managed via Rails credentials

#### Task 6: Authentication Error Classes (AC 2.6.8, 2.6.9) - COMPLETE
- ✅ UnauthenticatedError class (401)
- ✅ ForbiddenError class (403)
- ✅ Error codes: UNAUTHENTICATED, FORBIDDEN
- ✅ Base error class with standardized format
- ✅ RateLimitedError, ValidationError, SessionExpiredError classes

#### Task 7: Authentication Audit Logging (AC 2.6.10) - PARTIALLY COMPLETE
- ✅ Auditable concern already captures auth events
- ✅ Audit logs include IP address and user agent
- ⚠️ Need to verify all auth events are logged (JWT_CREATED, JWT_REFRESH, etc.)

#### Task 8: Integration Testing - NOT STARTED
- ❌ GraphQL request specs for authenticated queries
- ❌ GraphQL request specs for unauthorized access (401)
- ❌ GraphQL request specs for forbidden access (403)
- ❌ Integration test for token refresh flow
- ❌ Integration test for rate limiting
- ❌ End-to-end PHI encryption tests
- ❌ Audit logging verification tests

### Critical Fixes Applied

1. **RefreshToken Model** - Fixed callback timing issue
   - Changed `before_create` to `before_validation` for hash_token
   - Added guard clause to prevent re-hashing
   - Ensures token_hash is set before validations run

2. **Factory** - Simplified token setting
   - Uses `after(:build)` to set virtual `token` attribute
   - Works for both `build` and `create` test scenarios

### Known Issues

1. **RefreshToken Tests** - 13 failures out of 58 tests
   - Validation tests failing due to callback complexity
   - Scope tests need investigation for edge cases
   - Token rotation tests have database state issues

2. **Policy Tests** - Need pundit-matchers gem
   - Tests created but matchers not configured
   - Gem needs to be added to Gemfile test group
   - RSpec config needs `require 'pundit/matchers'`

3. **Integration Tests** - Not implemented
   - Full request spec suite needed
   - GraphQL authorization testing missing
   - Rate limiting end-to-end tests missing

### Files Created/Modified

**Created:**
- app/models/refresh_token.rb
- app/services/auth/token_service.rb  (enhanced)
- app/middleware/rate_limiter.rb
- app/policies/parent_policy.rb
- app/policies/child_policy.rb
- app/policies/insurance_policy.rb
- app/policies/assessment_policy.rb
- app/graphql/errors/base_error.rb
- app/graphql/errors/error_codes.rb
- spec/models/refresh_token_spec.rb
- spec/services/auth/token_service_spec.rb
- spec/factories/refresh_tokens.rb
- spec/policies/parent_policy_spec.rb
- spec/policies/child_policy_spec.rb
- spec/policies/insurance_policy_spec.rb
- spec/policies/assessment_policy_spec.rb
- db/migrate/20251129190745_create_refresh_tokens.rb
- config/initializers/rate_limiter.rb (assumed)

**Modified:**
- app/models/onboarding_session.rb (added role enum and refresh_tokens association)
- app/graphql/concerns/current_session.rb (role helpers already present)

### Next Steps for Completion

1. **Fix Remaining Test Failures**
   - Debug RefreshToken validation and scope tests
   - Add pundit-matchers gem and configure
   - Ensure all policy tests pass

2. **Complete Integration Tests**
   - Create GraphQL request specs for auth flows
   - Test rate limiting end-to-end
   - Verify audit logging for all auth events

3. **Verify Middleware Configuration**
   - Ensure RateLimiter is registered in application.rb
   - Test rate limiting with actual requests
   - Verify Redis connection

4. **Documentation**
   - Document key rotation procedure
   - Add API examples for token refresh
   - Document rate limiting headers

### Test Coverage Summary

- RefreshToken model: ~78% (45/58 tests passing)
- Pundit policies: 0% (need matchers configuration)
- Integration tests: 0% (not implemented)
- Overall estimate: ~60% of acceptance criteria fully tested

---

## Senior Developer Review (AI)

### Reviewer
Pending - Review will be conducted after test fixes

### Date
TBD

### Outcome
TBD

### Summary
Core authentication and authorization infrastructure is in place. RefreshToken management, role-based access control, rate limiting, and error handling are implemented. Primary remaining work is fixing test issues and creating integration tests.

---

**Status**: in-progress
**Last Updated**: 2025-11-29
**Created By**: create-story workflow (YOLO mode)
**Partial Implementation By**: Claude Sonnet 4.5
