# Epic Technical Specification: Foundation & Infrastructure

Date: 2025-11-28
Author: BMad
Epic ID: 1
Status: Draft

---

## Overview

Epic 1 establishes the foundational Ruby on Rails 7 API-only backend that will power Daybreak Health's Parent Onboarding AI platform. This greenfield foundation implements the core project scaffold, database schema, reusable patterns, and local development environment that enables all subsequent feature development across Epics 2-8.

The epic is a prerequisite for all other work, providing the Rails project structure with GraphQL API via graphql-ruby, PostgreSQL database with encrypted PHI storage, JWT authentication infrastructure, Docker-based development environment, and deployment configuration for Aptible. By completing this foundation, the development team gains a consistent, secure, HIPAA-ready codebase optimized for rapid feature development.

## Objectives and Scope

### In-Scope

- **Project Initialization:** Rails 7.x API-only mode with PostgreSQL, graphql-ruby, Sidekiq, Redis, JWT, and Pundit gems configured
- **Database Schema:** All core models (OnboardingSession, Parent, Child, Insurance, Assessment, Message, AuditLog) with UUID primary keys, proper indexes, and Rails 7 encryption for PHI fields
- **Core Patterns:** Encryptable concern for PHI encryption, Auditable concern for audit logging, JWT authentication service, Pundit authorization policies, and standardized GraphQL error handling
- **Local Development:** Docker Compose configuration for PostgreSQL 16.x and Redis 7.x, multi-stage Dockerfile for production builds, and Aptible deployment configuration
- **Code Standards:** RuboCop configuration, naming conventions (snake_case files, PascalCase classes), PHI-safe logging patterns

### Out-of-Scope

- Business logic implementation (sessions, conversations, insurance, etc.) - covered in Epics 2-7
- GraphQL mutations and queries beyond base schema - covered in subsequent epics
- External service integrations (AI providers, AWS Textract, SES) - covered in Epics 3-6
- Admin dashboard and analytics - covered in Epic 7
- Data rights implementation (export, deletion) - covered in Epic 8
- Frontend integration - separate repository

## System Architecture Alignment

This epic directly implements the foundational layers defined in the Architecture document:

| Architecture Component | Epic 1 Implementation | Stories |
|------------------------|----------------------|---------|
| Rails 7 API-only | Project scaffold with API-only mode | 1.1 |
| GraphQL via graphql-ruby | Schema setup, types, base classes | 1.1 |
| PostgreSQL 16.x | Database configuration, UUID IDs | 1.1, 1.2 |
| Active Record Models | All 7 core models with associations | 1.2 |
| Rails 7 Encryption | Encryptable concern for PHI | 1.3 |
| JWT Authentication | Auth::JwtService with RS256 | 1.3 |
| Pundit Authorization | Base policies for RBAC | 1.3 |
| Sidekiq + Redis | Background job infrastructure | 1.1, 1.4 |
| Docker Development | docker-compose.dev.yml | 1.4 |
| Aptible Deployment | Dockerfile, Procfile, Aptfile | 1.4 |

**Constraints from Architecture:**
- All PHI fields must use Rails 7 built-in encryption (AES-256-GCM)
- JWT tokens expire in 1 hour with 7-day refresh tokens
- All tables use UUID primary keys
- PHI-safe logging (never log actual PHI values)
- GraphQL field names in camelCase, Ruby in snake_case

---

## Detailed Design

### Services and Modules

| Module | Location | Responsibility | Story |
|--------|----------|----------------|-------|
| **GraphQL Schema** | `app/graphql/daybreak_health_schema.rb` | Root schema definition with query, mutation, subscription types | 1.1 |
| **Base Types** | `app/graphql/types/` | BaseObject, BaseInputObject, BaseEnum, BaseScalar | 1.1 |
| **Auth::JwtService** | `app/services/auth/jwt_service.rb` | JWT encoding/decoding with HS256, token validation | 1.3 |
| **Auth::TokenService** | `app/services/auth/token_service.rb` | Refresh token management, session-token mapping | 1.3 |
| **Encryptable Concern** | `app/models/concerns/encryptable.rb` | PHI field encryption via Rails 7 `encrypts` | 1.3 |
| **Auditable Concern** | `app/models/concerns/auditable.rb` | Automatic audit log entries on model changes | 1.3 |
| **ApplicationPolicy** | `app/policies/application_policy.rb` | Base Pundit policy with default deny | 1.3 |
| **GraphqlController** | `app/controllers/graphql_controller.rb` | GraphQL endpoint, context injection, error handling | 1.1 |
| **ApplicationJob** | `app/jobs/application_job.rb` | Base Sidekiq job class with retry configuration | 1.1 |

**Service Pattern (from Architecture):**

```ruby
# app/services/auth/jwt_service.rb
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

### Data Models and Contracts

**Entity Relationship Diagram:**

```
OnboardingSession (1) ──── (0..1) Parent
        │
        ├──── (0..1) Child
        │
        ├──── (0..1) Insurance
        │
        ├──── (0..1) Assessment
        │
        ├──── (0..*) Message
        │
        └──── (0..*) AuditLog
```

**Model Definitions:**

| Model | Table | Key Fields | Encrypted PHI | Indexes |
|-------|-------|------------|---------------|---------|
| **OnboardingSession** | `onboarding_sessions` | id (uuid), status (enum), progress (jsonb), expires_at, referral_source | None | status, created_at |
| **Parent** | `parents` | id (uuid), onboarding_session_id, relationship, is_guardian | email, phone, first_name, last_name | onboarding_session_id (unique) |
| **Child** | `children` | id (uuid), onboarding_session_id, gender, school_name, grade | first_name, last_name, date_of_birth | onboarding_session_id (unique) |
| **Insurance** | `insurances` | id (uuid), onboarding_session_id, payer_name, verification_status (enum), verification_result (jsonb) | member_id, group_number, card_image_front, card_image_back | onboarding_session_id (unique) |
| **Assessment** | `assessments` | id (uuid), onboarding_session_id, risk_flags (array), consent_given | responses (jsonb), summary | onboarding_session_id (unique) |
| **Message** | `messages` | id (uuid), onboarding_session_id, role (enum), metadata (jsonb) | content | [onboarding_session_id, created_at] |
| **AuditLog** | `audit_logs` | id (uuid), onboarding_session_id, user_id, action, resource, resource_id, details (jsonb), ip_address, user_agent | None | onboarding_session_id, created_at, [resource, resource_id] |

**Enums:**

```ruby
# OnboardingSession.status
enum :status, {
  started: 0,
  in_progress: 1,
  insurance_pending: 2,
  assessment_complete: 3,
  submitted: 4,
  abandoned: 5,
  expired: 6
}

# Insurance.verification_status
enum :verification_status, {
  pending: 0,
  in_progress: 1,
  verified: 2,
  failed: 3,
  manual_review: 4,
  self_pay: 5
}

# Message.role
enum :role, { user: 0, assistant: 1, system: 2 }
```

**Encryptable Concern Implementation:**

```ruby
# app/models/concerns/encryptable.rb
module Encryptable
  extend ActiveSupport::Concern

  class_methods do
    def encrypts_phi(*attributes)
      attributes.each do |attr|
        encrypts attr, deterministic: false
      end
    end
  end
end

# Usage in Parent model
class Parent < ApplicationRecord
  include Encryptable
  include Auditable

  belongs_to :onboarding_session

  encrypts_phi :email, :phone, :first_name, :last_name

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :relationship, presence: true
  validates :is_guardian, inclusion: { in: [true, false] }
end
```

### APIs and Interfaces

**GraphQL Schema Structure (Story 1.1):**

```graphql
type Query {
  # Placeholder for Epic 2+ queries
  _empty: String
}

type Mutation {
  # Placeholder for Epic 2+ mutations
  _empty: String
}

type Subscription {
  # Placeholder for Epic 2+ subscriptions
  _empty: String
}

# Base types defined in Epic 1
scalar DateTime
scalar JSON
scalar UUID

enum SessionStatus {
  STARTED
  IN_PROGRESS
  INSURANCE_PENDING
  ASSESSMENT_COMPLETE
  SUBMITTED
  ABANDONED
  EXPIRED
}

enum VerificationStatus {
  PENDING
  IN_PROGRESS
  VERIFIED
  FAILED
  MANUAL_REVIEW
  SELF_PAY
}

enum MessageRole {
  USER
  ASSISTANT
  SYSTEM
}
```

**GraphQL Error Response Format:**

```json
{
  "errors": [{
    "message": "Human-readable message",
    "extensions": {
      "code": "ERROR_CODE",
      "timestamp": "2025-11-28T00:00:00Z",
      "path": ["mutation", "createSession"]
    }
  }]
}
```

**Error Codes (from Architecture):**

| Code | HTTP Equiv | Meaning |
|------|------------|---------|
| `UNAUTHENTICATED` | 401 | Invalid/missing auth |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource doesn't exist |
| `VALIDATION_ERROR` | 400 | Invalid input |
| `SESSION_EXPIRED` | 401 | Session timed out |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Unexpected error |

### Workflows and Sequencing

**Story Implementation Sequence:**

```
Story 1.1: Project Scaffolding & Core Setup
    │
    ├── rails new daybreak-health-backend --api --database=postgresql --skip-test
    ├── bundle add graphql sidekiq redis jwt bcrypt pundit
    ├── rails generate graphql:install
    ├── Configure project structure per Architecture doc
    └── Setup RuboCop and code standards
          │
          ▼
Story 1.2: Database Schema & Active Record Models (depends on 1.1)
    │
    ├── Create 7 migrations for all tables
    ├── Define models with associations and validations
    ├── Configure UUID primary keys
    └── rails db:migrate
          │
          ▼
Story 1.3: Common Concerns & Core Patterns (depends on 1.1)
    │
    ├── Implement Encryptable concern
    ├── Implement Auditable concern
    ├── Implement Auth::JwtService
    ├── Implement base Pundit policies
    └── Configure GraphQL error handling
          │
          ▼
Story 1.4: Docker & Local Development Environment (depends on 1.1)
    │
    ├── Create docker-compose.dev.yml
    ├── Create multi-stage Dockerfile
    ├── Create Aptfile and Procfile
    └── Verify full stack starts successfully
```

**Development Environment Startup Flow:**

```
1. docker-compose -f docker/docker-compose.dev.yml up -d db redis
       │
       ▼
2. Wait for health checks (PostgreSQL ready, Redis ping)
       │
       ▼
3. rails db:create db:migrate (first time only)
       │
       ▼
4. rails server (port 3000)
       │
       ▼
5. bundle exec sidekiq (separate terminal)
       │
       ▼
6. Access GraphiQL at http://localhost:3000/graphiql
```

---

## Non-Functional Requirements

### Performance

| Metric | Requirement | Epic 1 Implementation |
|--------|-------------|----------------------|
| API Response Time | p95 < 500ms | Optimized Rails configuration, database connection pooling |
| Database Queries | N+1 prevention | GraphQL batch loading patterns established |
| Cold Start | < 5s | Multi-stage Docker build with bootsnap precompilation |
| Memory Footprint | < 512MB base | Alpine-based Docker image, tuned Puma workers |

**Configuration:**
- Puma: 2 workers, 5 threads per worker (adjustable via env)
- PostgreSQL connection pool: 10 connections per worker
- Redis connection pool: 5 connections

### Security

| Requirement | Implementation | Story |
|-------------|----------------|-------|
| PHI Encryption at Rest | Rails 7 `encrypts` with AES-256-GCM | 1.3 |
| PHI Encryption in Transit | TLS 1.3 enforced (Aptible handles) | 1.4 |
| JWT Authentication | HS256 algorithm, 1-hour expiration | 1.3 |
| Secrets Management | Rails credentials (encrypted) | 1.1 |
| SQL Injection Prevention | Active Record parameterized queries | 1.2 |
| Mass Assignment Protection | Strong parameters in GraphQL resolvers | 1.1 |
| CORS Configuration | Whitelist frontend domain only | 1.1 |

**Required Environment Variables:**
```bash
# Secrets (Rails credentials or env for dev)
RAILS_MASTER_KEY=<32-char-key>
JWT_SECRET=<min-32-char-secret>

# Database
DATABASE_URL=postgres://user:pass@host:5432/db_name

# Redis
REDIS_URL=redis://localhost:6379/0

# Encryption (Rails credentials)
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<generated>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<generated>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<generated>
```

### Reliability/Availability

| Requirement | Implementation |
|-------------|----------------|
| Target Uptime | 99.9% (Aptible SLA) |
| Database Backups | Automated via Aptible (point-in-time recovery) |
| Graceful Shutdown | Puma drain on SIGTERM |
| Health Check Endpoint | `/health` returns 200 when app ready |
| Dependency Health | PostgreSQL and Redis connectivity checks |

**Health Check Implementation:**
```ruby
# config/routes.rb
get '/health', to: proc { [200, {}, ['OK']] }

# Or more comprehensive:
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def show
    checks = {
      database: ActiveRecord::Base.connection.active?,
      redis: Redis.current.ping == 'PONG'
    }
    status = checks.values.all? ? :ok : :service_unavailable
    render json: checks, status: status
  end
end
```

### Observability

| Component | Implementation | Story |
|-----------|----------------|-------|
| Request Logging | Rails logger with request ID | 1.1 |
| PHI-Safe Logging | Never log PHI values, only flags | 1.3 |
| Error Tracking | Exception notification (configurable) | 1.1 |
| Audit Trail | AuditLog model for all PHI access | 1.2, 1.3 |
| Metrics | Aptible metrics dashboard | 1.4 |

**PHI-Safe Logging Pattern:**
```ruby
# CORRECT - log existence, not values
Rails.logger.info("Session created", {
  session_id: session.id,
  has_parent_email: session.parent&.email.present?,
  status: session.status
})

# WRONG - never log PHI
# Rails.logger.info("Parent email: #{parent.email}")
```

---

## Dependencies and Integrations

### Ruby Gems (Gemfile)

| Gem | Version | Purpose | Story |
|-----|---------|---------|-------|
| `rails` | ~> 7.1 | Web framework | 1.1 |
| `pg` | ~> 1.5 | PostgreSQL adapter | 1.1 |
| `graphql` | ~> 2.2 | GraphQL API | 1.1 |
| `graphiql-rails` | ~> 1.9 | Development GraphQL IDE | 1.1 |
| `sidekiq` | ~> 7.2 | Background job processing | 1.1 |
| `redis` | ~> 5.0 | Redis client | 1.1 |
| `jwt` | ~> 2.7 | JWT encoding/decoding | 1.3 |
| `bcrypt` | ~> 3.1 | Password hashing | 1.3 |
| `pundit` | ~> 2.3 | Authorization | 1.3 |
| `bootsnap` | ~> 1.17 | Boot optimization | 1.1 |
| `puma` | ~> 6.4 | Web server | 1.1 |
| `rack-cors` | ~> 2.0 | CORS handling | 1.1 |

**Development/Test Gems:**
| Gem | Purpose |
|-----|---------|
| `rspec-rails` | Testing framework |
| `factory_bot_rails` | Test fixtures |
| `faker` | Test data generation |
| `rubocop-rails` | Code linting |
| `rubocop-rspec` | RSpec linting |

### Infrastructure Dependencies

| Service | Version | Local Dev | Production |
|---------|---------|-----------|------------|
| PostgreSQL | 16.x | Docker | Aptible managed |
| Redis | 7.x | Docker | Aptible managed |
| Ruby | 3.3.x | Local/Docker | Docker image |

### External Services (Future Epics - Not Implemented in Epic 1)

| Service | Purpose | Epic |
|---------|---------|------|
| Anthropic Claude API | Conversational AI | Epic 3 |
| OpenAI API | Backup AI provider | Epic 3 |
| AWS S3 | Insurance card storage | Epic 4 |
| AWS Textract | Insurance OCR | Epic 4 |
| AWS SES | Email notifications | Epic 6 |

---

## Acceptance Criteria (Authoritative)

### Story 1.1: Project Scaffolding & Core Setup

| AC ID | Criteria | Verification |
|-------|----------|--------------|
| 1.1.1 | Rails 7.x project created in API-only mode with PostgreSQL | `rails -v` shows 7.x, `config/application.rb` has `config.api_only = true` |
| 1.1.2 | GraphQL configured via graphql-ruby gem | `bundle show graphql` succeeds, `/graphiql` accessible in development |
| 1.1.3 | Project structure matches Architecture document | Directories exist: `app/graphql/`, `app/services/`, `app/policies/`, `app/jobs/` |
| 1.1.4 | RuboCop configured with project conventions | `.rubocop.yml` exists, `bundle exec rubocop` runs without config errors |
| 1.1.5 | `.env.example` created with all required environment variables | File contains DATABASE_URL, REDIS_URL, JWT_SECRET, RAILS_MASTER_KEY |
| 1.1.6 | `rails server` starts on port 3000 | Server responds to HTTP requests |
| 1.1.7 | GraphiQL accessible at `/graphiql` in development | Browser shows GraphiQL interface |

### Story 1.2: Database Schema & Active Record Models

| AC ID | Criteria | Verification |
|-------|----------|--------------|
| 1.2.1 | All 7 models created: OnboardingSession, Parent, Child, Insurance, Assessment, Message, AuditLog | Models exist in `app/models/` |
| 1.2.2 | All enums defined: status, verification_status, role | `OnboardingSession.statuses`, `Insurance.verification_statuses`, `Message.roles` return hashes |
| 1.2.3 | Proper relationships with foreign keys | `OnboardingSession.reflect_on_all_associations` returns correct associations |
| 1.2.4 | Indexes on: sessions.status, sessions.created_at, audit_logs.onboarding_session_id | `rails db:migrate:status` shows all migrations applied, schema has indexes |
| 1.2.5 | UUID IDs used for all primary keys | `schema.rb` shows `id: :uuid` for all tables |
| 1.2.6 | `created_at` and `updated_at` timestamps on all models | All models have `t.timestamps` in migration |
| 1.2.7 | `rails db:migrate` runs successfully | Exit code 0, no errors |

### Story 1.3: Common Concerns & Core Patterns

| AC ID | Criteria | Verification |
|-------|----------|--------------|
| 1.3.1 | `current_session` helper extracts session from GraphQL context | Helper method exists and returns session from context[:current_session] |
| 1.3.2 | Pundit policies for role-based access control | `ApplicationPolicy` exists with default deny, `OnboardingSessionPolicy` exists |
| 1.3.3 | JWT authentication via `Auth::JwtService` | `Auth::JwtService.encode` and `.decode` work correctly |
| 1.3.4 | `Encryptable` concern for PHI field encryption | Parent model PHI fields are encrypted (can't read raw from DB) |
| 1.3.5 | `Auditable` concern for automatic audit logging | Creating/updating auditable model creates AuditLog entry |
| 1.3.6 | Custom GraphQL error handling with standard codes | Errors return `{ message, extensions: { code, timestamp, path } }` format |
| 1.3.7 | Error codes match Architecture doc | UNAUTHENTICATED, FORBIDDEN, NOT_FOUND, VALIDATION_ERROR codes implemented |

### Story 1.4: Docker & Local Development Environment

| AC ID | Criteria | Verification |
|-------|----------|--------------|
| 1.4.1 | `docker-compose.dev.yml` defines PostgreSQL 16.x and Redis 7.x | File exists with correct image versions |
| 1.4.2 | PostgreSQL exposed on port 5432 with persistent volume | `docker-compose ps` shows postgres on 5432, volume persists data |
| 1.4.3 | Redis exposed on port 6379 | `redis-cli ping` returns PONG |
| 1.4.4 | Health checks configured for both services | `docker-compose ps` shows services as healthy |
| 1.4.5 | `Dockerfile` created for production builds | Multi-stage Dockerfile with ruby:3.3-alpine base |
| 1.4.6 | `.dockerignore` excludes vendor/bundle, .env, tmp/, log/ | File contains exclusions |
| 1.4.7 | `docker-compose up -d` starts dependencies | Both services start and pass health checks |
| 1.4.8 | Application connects successfully to both services | `rails console` can query DB, Redis.current.ping works |
| 1.4.9 | Sidekiq container configured | Procfile includes `worker: bundle exec sidekiq` |
| 1.4.10 | Aptible configuration present | `Aptfile` and `Procfile` exist |

---

## Traceability Mapping

| AC | Spec Section | Component/File | Test Type |
|----|--------------|----------------|-----------|
| 1.1.1 | Project Initialization | `config/application.rb` | Manual |
| 1.1.2 | GraphQL Schema | `app/graphql/daybreak_health_schema.rb` | Integration |
| 1.1.3 | Project Structure | Directory structure | Manual |
| 1.1.4 | Code Standards | `.rubocop.yml` | CI/Lint |
| 1.1.5 | Configuration | `.env.example` | Manual |
| 1.1.6 | Server | `config/puma.rb` | Integration |
| 1.1.7 | Development Tools | `config/routes.rb` | Manual |
| 1.2.1 | Data Models | `app/models/*.rb` | Unit |
| 1.2.2 | Enums | Model classes | Unit |
| 1.2.3 | Associations | Model associations | Unit |
| 1.2.4 | Indexes | `db/schema.rb` | Migration |
| 1.2.5 | UUID IDs | Migrations | Migration |
| 1.2.6 | Timestamps | Migrations | Migration |
| 1.2.7 | Migration | `db/migrate/*.rb` | Migration |
| 1.3.1 | Context Helper | `app/graphql/` or `app/controllers/` | Unit |
| 1.3.2 | Authorization | `app/policies/*.rb` | Unit |
| 1.3.3 | Authentication | `app/services/auth/jwt_service.rb` | Unit |
| 1.3.4 | PHI Encryption | `app/models/concerns/encryptable.rb` | Integration |
| 1.3.5 | Audit Logging | `app/models/concerns/auditable.rb` | Integration |
| 1.3.6 | Error Handling | GraphQL error classes | Integration |
| 1.3.7 | Error Codes | Error handling module | Unit |
| 1.4.1 | Docker Compose | `docker/docker-compose.dev.yml` | Integration |
| 1.4.2 | PostgreSQL | Docker Compose | Integration |
| 1.4.3 | Redis | Docker Compose | Integration |
| 1.4.4 | Health Checks | Docker Compose | Integration |
| 1.4.5 | Dockerfile | `docker/Dockerfile` | Build |
| 1.4.6 | Docker Ignore | `.dockerignore` | Build |
| 1.4.7 | Docker Up | Docker Compose | Integration |
| 1.4.8 | Connectivity | Application | Integration |
| 1.4.9 | Sidekiq | `Procfile` | Integration |
| 1.4.10 | Aptible | `Aptfile`, `Procfile` | Manual |

---

## Risks, Assumptions, Open Questions

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **R1:** Rails 7 encryption key rotation complexity | Medium | High | Document key rotation procedure early, test with sample data |
| **R2:** GraphQL N+1 query issues in future epics | High | Medium | Establish batch loading patterns in Epic 1, add graphql-batch gem |
| **R3:** Docker environment differences from Aptible production | Low | Medium | Use same base images, test deployment to Aptible staging early |
| **R4:** UUID performance impact on large tables | Low | Low | PostgreSQL handles UUIDs well; add indexes as specified |

### Assumptions

| ID | Assumption | Validation |
|----|------------|------------|
| **A1** | Team has Ruby/Rails expertise | Confirmed in Architecture ADR-001 |
| **A2** | Aptible provides PostgreSQL 16 and Redis 7 | Verify Aptible database versions |
| **A3** | RAILS_MASTER_KEY will be securely managed | Confirm secrets management approach with DevOps |
| **A4** | RSpec is preferred over Minitest | Team consensus per Architecture doc |
| **A5** | graphql-ruby 2.x is stable for production | Widely used, well-maintained |

### Open Questions

| ID | Question | Owner | Due Date | Resolution |
|----|----------|-------|----------|------------|
| **Q1** | Should we use Solid Cable (database-backed) or Redis for Action Cable in production? | Architect | Before Epic 2 | Depends on Aptible Redis availability/cost |
| **Q2** | Do we need database partitioning for audit_logs from day one? | DBA | Before Epic 8 | Start without, add if volume requires |
| **Q3** | Which RuboCop rules should be customized for this project? | Tech Lead | Story 1.1 | Create `.rubocop.yml` with reasonable defaults, adjust as needed |

---

## Test Strategy Summary

### Test Levels

| Level | Framework | Coverage Target | Scope |
|-------|-----------|-----------------|-------|
| **Unit Tests** | RSpec | 90%+ | Models, services, concerns |
| **Integration Tests** | RSpec + rack-test | Key flows | GraphQL queries/mutations |
| **Linting** | RuboCop | 100% pass | All Ruby files |
| **Security Scan** | Brakeman | 0 high/medium | Security vulnerabilities |

### Epic 1 Specific Tests

**Story 1.1 Tests:**
- GraphQL schema loads without errors
- GraphiQL route accessible in development
- Health check endpoint returns 200

**Story 1.2 Tests:**
- Each model can be created with valid attributes
- Associations work correctly (e.g., `session.parent`)
- Enums return expected values
- UUID IDs are generated correctly
- Validations reject invalid data

**Story 1.3 Tests:**
- `Auth::JwtService.encode` produces valid JWT
- `Auth::JwtService.decode` extracts payload correctly
- Expired tokens are rejected
- `Encryptable` concern encrypts PHI fields (verify encrypted in DB)
- `Auditable` concern creates audit log entries
- Pundit policies deny by default
- GraphQL errors return correct format

**Story 1.4 Tests:**
- Docker Compose starts all services
- Application connects to PostgreSQL
- Application connects to Redis
- Sidekiq can process jobs
- Docker build completes successfully

### Test Commands

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/onboarding_session_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec

# Run linter
bundle exec rubocop

# Run security scan
bundle exec brakeman -q

# Run all checks (CI)
bundle exec rubocop && bundle exec brakeman -q && bundle exec rspec
```

### CI Pipeline (Recommended)

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_PASSWORD: postgres
        ports: ['5432:5432']
      redis:
        image: redis:7-alpine
        ports: ['6379:6379']
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bundle exec rubocop
      - run: bundle exec brakeman -q
      - run: bundle exec rspec
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/test
          REDIS_URL: redis://localhost:6379/0
```

---

_Generated by BMAD Epic Tech Context Workflow v6_
_Date: 2025-11-28_
_Epic: 1 - Foundation & Infrastructure_
