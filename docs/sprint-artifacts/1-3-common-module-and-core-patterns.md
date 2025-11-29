# Story 1.3: Common Concerns & Core Patterns

Status: ready-for-dev

## Story

As a developer,
I want reusable concerns, policies, and error handling,
so that all modules follow consistent patterns for auth, logging, and error handling.

## Acceptance Criteria

1. **AC 1.3.1**: current_session helper extracts session from GraphQL context
2. **AC 1.3.2**: Pundit policies for role-based access control
3. **AC 1.3.3**: JWT authentication via Auth::JwtService
4. **AC 1.3.4**: Encryptable concern for PHI field encryption
5. **AC 1.3.5**: Auditable concern for automatic audit logging
6. **AC 1.3.6**: Custom GraphQL error handling with standard codes
7. **AC 1.3.7**: Error codes match Architecture doc: UNAUTHENTICATED, FORBIDDEN, NOT_FOUND, VALIDATION_ERROR, etc.

## Tasks / Subtasks

- [ ] **Task 1**: Create Encryptable concern with encrypts_phi method (AC: #1.3.4)
  - [ ] 1.1: Define Encryptable module in `app/models/concerns/encryptable.rb`
  - [ ] 1.2: Implement `encrypts_phi` class method for field encryption
  - [ ] 1.3: Add PHI-safe logging (log existence flags only, never actual values)
  - [ ] 1.4: Write RSpec tests for encryption/decryption

- [ ] **Task 2**: Create Auditable concern for automatic audit logging (AC: #1.3.5)
  - [ ] 2.1: Define Auditable module in `app/models/concerns/auditable.rb`
  - [ ] 2.2: Implement after_create, after_update, after_destroy callbacks
  - [ ] 2.3: Create audit log entries with actor, action, and timestamp
  - [ ] 2.4: Ensure PHI-safe logging (redact sensitive fields)
  - [ ] 2.5: Write RSpec tests for audit trail creation

- [ ] **Task 3**: Implement Auth::JwtService for JWT encoding/decoding (AC: #1.3.3)
  - [ ] 3.1: Create `app/services/auth/jwt_service.rb`
  - [ ] 3.2: Implement `encode` method with HS256 algorithm, 1-hour expiration
  - [ ] 3.3: Implement `decode` method with error handling
  - [ ] 3.4: Add iat (issued at) and exp (expiration) claims
  - [ ] 3.5: Configure JWT secret from Rails credentials
  - [ ] 3.6: Write RSpec tests for encoding, decoding, and expiration

- [ ] **Task 4**: Implement Auth::TokenService for refresh token management (AC: #1.3.3)
  - [ ] 4.1: Create `app/services/auth/token_service.rb`
  - [ ] 4.2: Implement `generate_refresh_token` method
  - [ ] 4.3: Implement `validate_refresh_token` method
  - [ ] 4.4: Add token rotation logic (invalidate old tokens on refresh)
  - [ ] 4.5: Write RSpec tests for token lifecycle

- [ ] **Task 5**: Create ApplicationPolicy with default deny (AC: #1.3.2)
  - [ ] 5.1: Create `app/policies/application_policy.rb`
  - [ ] 5.2: Set all default permissions to false (deny by default)
  - [ ] 5.3: Define standard policy methods: index?, show?, create?, update?, destroy?
  - [ ] 5.4: Add user and record accessor methods
  - [ ] 5.5: Write RSpec tests for default deny behavior

- [ ] **Task 6**: Create OnboardingSessionPolicy (AC: #1.3.2)
  - [ ] 6.1: Create `app/policies/onboarding_session_policy.rb`
  - [ ] 6.2: Implement create? (allow anonymous users)
  - [ ] 6.3: Implement show? (allow session owner only)
  - [ ] 6.4: Implement update? (allow session owner only)
  - [ ] 6.5: Ensure policy respects session ownership rules
  - [ ] 6.6: Write RSpec tests for all policy methods

- [ ] **Task 7**: Add current_session helper to GraphQL context (AC: #1.3.1)
  - [ ] 7.1: Create `app/graphql/concerns/current_session.rb`
  - [ ] 7.2: Implement `current_session` method to extract from context
  - [ ] 7.3: Handle missing or invalid session gracefully
  - [ ] 7.4: Add method to GraphQL base mutation and query classes
  - [ ] 7.5: Write RSpec tests for session extraction

- [ ] **Task 8**: Implement custom GraphQL error handling (AC: #1.3.6)
  - [ ] 8.1: Create `app/graphql/errors/` directory
  - [ ] 8.2: Define base error class with message and extensions
  - [ ] 8.3: Implement error formatter in GraphQL schema
  - [ ] 8.4: Add timestamp and path to error extensions
  - [ ] 8.5: Ensure PHI-safe error messages (no sensitive data in errors)
  - [ ] 8.6: Write RSpec tests for error formatting

- [ ] **Task 9**: Define error codes as constants (AC: #1.3.7)
  - [ ] 9.1: Create `app/graphql/errors/error_codes.rb`
  - [ ] 9.2: Define UNAUTHENTICATED constant
  - [ ] 9.3: Define FORBIDDEN constant
  - [ ] 9.4: Define NOT_FOUND constant
  - [ ] 9.5: Define VALIDATION_ERROR constant
  - [ ] 9.6: Define INTERNAL_ERROR constant
  - [ ] 9.7: Document each error code with usage examples

- [ ] **Task 10**: Write RSpec tests for all services and concerns
  - [ ] 10.1: Create `spec/models/concerns/encryptable_spec.rb`
  - [ ] 10.2: Create `spec/models/concerns/auditable_spec.rb`
  - [ ] 10.3: Create `spec/services/auth/jwt_service_spec.rb`
  - [ ] 10.4: Create `spec/services/auth/token_service_spec.rb`
  - [ ] 10.5: Create `spec/policies/application_policy_spec.rb`
  - [ ] 10.6: Create `spec/policies/onboarding_session_policy_spec.rb`
  - [ ] 10.7: Create `spec/graphql/errors/error_handling_spec.rb`
  - [ ] 10.8: Ensure all tests pass and achieve >90% coverage

## Dev Notes

### Architecture Patterns and Constraints

- **Concerns Pattern**: Reusable modules in `app/models/concerns/` following Rails conventions
- **Service Object Pattern**: Stateless service classes in `app/services/` namespace
- **Policy Pattern**: Pundit policies in `app/policies/` for authorization
- **JWT Standard**: HS256 algorithm with 1-hour expiration, issued-at and expiration claims
- **PHI Safety**: Never log actual PHI values, only existence flags or redacted placeholders
- **Error Format**: GraphQL errors include `{ message, extensions: { code, timestamp, path } }`
- **Default Deny**: All policies deny by default, explicit allow required

### Source Tree Components to Touch

```
app/
├── models/concerns/
│   ├── encryptable.rb          # PHI encryption concern
│   └── auditable.rb            # Audit logging concern
├── services/auth/
│   ├── jwt_service.rb          # JWT encode/decode
│   └── token_service.rb        # Refresh token management
├── policies/
│   ├── application_policy.rb   # Base policy (default deny)
│   └── onboarding_session_policy.rb  # Session-specific policy
└── graphql/
    ├── concerns/
    │   └── current_session.rb  # Session extraction helper
    └── errors/
        ├── error_codes.rb      # Standard error code constants
        └── base_error.rb       # Base error class

spec/
├── models/concerns/
├── services/auth/
├── policies/
└── graphql/errors/
```

### Testing Standards Summary

- **Unit Tests**: All services, concerns, and policies require RSpec tests
- **Coverage**: Minimum 90% code coverage for all new code
- **Security Tests**: Verify JWT expiration, token invalidation, default deny
- **PHI Safety Tests**: Ensure no PHI appears in logs or error messages
- **Edge Cases**: Test expired tokens, missing sessions, unauthorized access
- **Integration Tests**: Verify GraphQL context integration with current_session

### Project Structure Notes

#### Alignment with Unified Project Structure

This story implements foundational cross-cutting concerns that align with the unified project structure:

- **Concerns Directory** (`app/models/concerns/`): Reusable modules following Rails Active Support::Concern pattern
- **Services Directory** (`app/services/`): Namespaced service objects (Auth::JwtService, Auth::TokenService)
- **Policies Directory** (`app/policies/`): Pundit authorization policies with default deny
- **GraphQL Structure** (`app/graphql/`): Custom error handling and context helpers

All components follow the modular architecture defined in the tech spec, ensuring consistency across the codebase.

### References

- [Source: docs/architecture.md#Security Architecture]
- [Source: docs/architecture.md#Error Handling]
- [Source: docs/tech-spec.md#1.3 Common Concerns & Core Patterns]
- [Source: docs/epics.md#Epic 1: Foundation & Core Services]

### Auth::JwtService Implementation Pattern

```ruby
module Auth
  class JwtService
    SECRET = Rails.application.credentials.jwt_secret!
    ALGORITHM = 'HS256'

    def self.encode(payload, exp: 1.hour.from_now)
      payload[:exp] = exp.to_i
      payload[:iat] = Time.current.to_i
      JWT.encode(payload, SECRET, ALGORITHM)
    end

    def self.decode(token)
      decoded = JWT.decode(token, SECRET, true, algorithm: ALGORITHM)
      HashWithIndifferentAccess.new(decoded.first)
    rescue JWT::DecodeError => e
      Rails.logger.warn("JWT decode failed: #{e.message}")
      nil
    end
  end
end
```

### PHI-Safe Logging Examples

```ruby
# GOOD - Log existence flags only
Rails.logger.info("User #{user_id} has PHI: #{user.phi_fields.present?}")

# BAD - Never log actual PHI values
Rails.logger.info("User #{user_id} SSN: #{user.ssn}")  # NEVER DO THIS
```

### Error Response Format

```json
{
  "errors": [
    {
      "message": "Session not found",
      "extensions": {
        "code": "NOT_FOUND",
        "timestamp": "2025-11-29T10:30:00Z",
        "path": ["mutation", "updateOnboardingSession"]
      }
    }
  ]
}
```

## Dev Agent Record

### Context Reference
- `docs/sprint-artifacts/1-3-common-module-and-core-patterns.context.xml`

### Agent Model Used
<!-- Will be populated during implementation -->
TBD

### Debug Log References
<!-- Will be populated during implementation -->

### Completion Notes List
<!-- Will be populated during implementation -->

### File List
<!-- Final list of files created/modified will be populated during implementation -->

**Expected Files:**
- `app/models/concerns/encryptable.rb`
- `app/models/concerns/auditable.rb`
- `app/services/auth/jwt_service.rb`
- `app/services/auth/token_service.rb`
- `app/policies/application_policy.rb`
- `app/policies/onboarding_session_policy.rb`
- `app/graphql/concerns/current_session.rb`
- `app/graphql/errors/error_codes.rb`
- `app/graphql/errors/base_error.rb`
- RSpec test files for all components
