# Daybreak Health Backend - Architecture

## Executive Summary

This architecture defines a **Ruby on Rails 7 API-only backend** optimized for HIPAA-compliant healthcare data handling. The system uses Rails conventions with clear separation between API, business logic, and data access layers. All architectural decisions prioritize security, auditability, and developer productivity.

## Technology Requirements

| Category | Technology | Notes |
|----------|------------|-------|
| **Back-end** | Ruby on Rails 7 | API-only mode |
| **Database** | PostgreSQL 16 | Primary data store |
| **Front-end** | Next.js | Separate repository |
| **AI Frameworks** | Agnostic | Support Claude, OpenAI, etc. |
| **Dev Tools** | Docker, Postman | Containerization, API testing |
| **Cloud** | AWS S3, Aptible | Storage, hosting |
| **API** | GraphQL | graphql-ruby gem |

## Project Initialization

First implementation story should execute:

```bash
rails new daybreak-health-backend --api --database=postgresql --skip-test
cd daybreak-health-backend
bundle add graphql sidekiq redis action_cable_redis_backplane
bundle add aws-sdk-s3 aws-sdk-textract
bundle add jwt bcrypt pundit
bundle add anthropic ruby-openai  # AI providers
rails generate graphql:install
```

This establishes the base architecture with:
- Rails 7 in API-only mode
- PostgreSQL database
- GraphQL via graphql-ruby
- Sidekiq for background jobs
- JWT authentication
- AI provider flexibility

---

## Decision Summary

| Category | Decision | Version | Affects FRs | Rationale |
|----------|----------|---------|-------------|-----------|
| Runtime | Ruby | 3.3.x | All | Stable, team expertise |
| Framework | Rails | 7.x | All | API-only, conventions, productivity |
| Language | Ruby | 3.3 | All | Team expertise, rapid development |
| API Protocol | GraphQL | - | All client FRs | Flexible queries, subscriptions |
| GraphQL Server | graphql-ruby | 2.x | FR7-FR12 | Mature, well-documented |
| ORM | Active Record | 7.x | All data FRs | Rails default, migrations |
| Database | PostgreSQL | 16.x | All data FRs | HIPAA-ready, JSON support |
| Cache/Queue | Redis | 7.x | FR3, FR19-24 | Session state, Sidekiq backend |
| Job Queue | Sidekiq | 7.x | FR19-24, FR31-35 | Reliable, battle-tested |
| Auth | JWT + Refresh | - | FR1-6, FR43-47 | Stateless, secure |
| File Storage | AWS S3 | - | FR19-20 | HIPAA BAA available |
| LLM Provider | Agnostic | - | FR7-12, FR26-30 | Claude/OpenAI support |
| OCR Service | AWS Textract | - | FR19-20 | HIPAA BAA, insurance extraction |
| Email | AWS SES | - | FR31-35 | HIPAA BAA, transactional |
| Real-time | Action Cable | - | Subscriptions | Built-in Rails WebSocket |
| Testing | RSpec | 3.x | All | Rails standard |
| Deployment | Aptible + Docker | - | All | HIPAA-compliant hosting |

---

## Project Structure

```
daybreak-health-backend/
├── app/
│   ├── channels/                    # Action Cable channels
│   │   ├── application_cable/
│   │   │   ├── channel.rb
│   │   │   └── connection.rb        # JWT auth for WebSocket
│   │   └── graphql_channel.rb       # GraphQL subscription handler
│   │
│   ├── graphql/                     # GraphQL schema
│   │   ├── daybreak_health_schema.rb
│   │   ├── types/
│   │   │   ├── base_object.rb
│   │   │   ├── query_type.rb
│   │   │   ├── mutation_type.rb
│   │   │   ├── subscription_type.rb
│   │   │   ├── onboarding_session_type.rb
│   │   │   ├── parent_type.rb
│   │   │   ├── child_type.rb
│   │   │   ├── insurance_type.rb
│   │   │   ├── assessment_type.rb
│   │   │   ├── message_type.rb
│   │   │   └── enums/
│   │   │       ├── session_status_enum.rb
│   │   │       ├── verification_status_enum.rb
│   │   │       └── message_role_enum.rb
│   │   ├── mutations/
│   │   │   ├── base_mutation.rb
│   │   │   ├── sessions/
│   │   │   │   ├── create_session.rb
│   │   │   │   ├── update_progress.rb
│   │   │   │   └── abandon_session.rb
│   │   │   ├── conversation/
│   │   │   │   └── send_message.rb
│   │   │   ├── intake/
│   │   │   │   ├── submit_parent_info.rb
│   │   │   │   └── submit_child_info.rb
│   │   │   ├── insurance/
│   │   │   │   ├── upload_card.rb
│   │   │   │   ├── submit_info.rb
│   │   │   │   └── verify_eligibility.rb
│   │   │   └── assessment/
│   │   │       └── submit_response.rb
│   │   └── subscriptions/
│   │       ├── session_updated.rb
│   │       ├── message_received.rb
│   │       └── eligibility_changed.rb
│   │
│   ├── models/                      # Active Record models
│   │   ├── application_record.rb
│   │   ├── onboarding_session.rb
│   │   ├── parent.rb
│   │   ├── child.rb
│   │   ├── insurance.rb
│   │   ├── assessment.rb
│   │   ├── message.rb
│   │   ├── audit_log.rb
│   │   └── concerns/
│   │       ├── encryptable.rb       # PHI encryption concern
│   │       └── auditable.rb         # Audit logging concern
│   │
│   ├── services/                    # Business logic services
│   │   ├── ai/
│   │   │   ├── client.rb            # Agnostic AI client
│   │   │   ├── providers/
│   │   │   │   ├── anthropic_provider.rb
│   │   │   │   └── openai_provider.rb
│   │   │   ├── context_manager.rb
│   │   │   └── prompts/
│   │   │       ├── intake_prompt.rb
│   │   │       ├── insurance_prompt.rb
│   │   │       └── assessment_prompt.rb
│   │   ├── insurance/
│   │   │   ├── ocr_service.rb
│   │   │   ├── card_parser.rb
│   │   │   └── eligibility_service.rb
│   │   ├── notification/
│   │   │   ├── email_service.rb
│   │   │   └── alert_service.rb
│   │   └── auth/
│   │       ├── jwt_service.rb
│   │       └── token_service.rb
│   │
│   ├── jobs/                        # Sidekiq background jobs
│   │   ├── application_job.rb
│   │   ├── ocr_processing_job.rb
│   │   ├── eligibility_check_job.rb
│   │   ├── email_delivery_job.rb
│   │   ├── session_cleanup_job.rb
│   │   └── risk_alert_job.rb
│   │
│   ├── policies/                    # Pundit authorization
│   │   ├── application_policy.rb
│   │   ├── onboarding_session_policy.rb
│   │   └── admin_policy.rb
│   │
│   └── controllers/
│       ├── application_controller.rb
│       └── graphql_controller.rb
│
├── config/
│   ├── database.yml
│   ├── cable.yml                    # Action Cable config
│   ├── sidekiq.yml
│   ├── initializers/
│   │   ├── cors.rb
│   │   ├── encryption.rb            # PHI encryption setup
│   │   └── ai_providers.rb
│   └── routes.rb
│
├── db/
│   ├── migrate/
│   └── schema.rb
│
├── spec/                            # RSpec tests
│   ├── models/
│   ├── services/
│   ├── graphql/
│   ├── jobs/
│   └── support/
│
├── docker/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── docker-compose.dev.yml
│
├── .env.example
├── Gemfile
└── Aptfile                          # Aptible configuration
```

---

## FR Category to Architecture Mapping

| FR Category | Primary Location | Supporting | Key Patterns |
|-------------|-----------------|------------|--------------|
| Session Management (FR1-6) | `models/`, `mutations/sessions/` | `services/auth/` | State machine, Redis caching |
| Conversational AI (FR7-12) | `services/ai/` | `mutations/conversation/` | Provider pattern, streaming |
| Data Collection (FR13-18) | `mutations/intake/` | `models/` | Encrypted fields, validation |
| Insurance (FR19-25) | `services/insurance/`, `jobs/` | `mutations/insurance/` | Async OCR, adapter pattern |
| Assessment (FR26-30) | `services/ai/`, `mutations/assessment/` | `jobs/` | Risk detection, escalation |
| Notifications (FR31-35) | `services/notification/`, `jobs/` | - | Queue-based, templates |
| Admin (FR36-42) | `mutations/admin/`, `types/` | `policies/` | RBAC, analytics |
| Compliance (FR43-47) | `concerns/`, `models/audit_log.rb` | All | Encryption, logging, RBAC |

---

## Implementation Patterns

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Files | snake_case | `onboarding_session.rb` |
| Classes | PascalCase | `OnboardingSession` |
| Methods | snake_case | `create_session` |
| Variables | snake_case | `session_id` |
| Constants | SCREAMING_SNAKE | `MAX_SESSION_DURATION` |
| Database Tables | snake_case plural | `onboarding_sessions` |
| Database Columns | snake_case | `created_at` |
| GraphQL Types | PascalCase | `OnboardingSessionType` |
| GraphQL Fields | camelCase | `sessionId` |
| Environment Vars | SCREAMING_SNAKE | `DATABASE_URL` |

### Service Pattern

```ruby
# app/services/ai/client.rb
class Ai::Client
  def initialize(provider: nil)
    @provider = provider || default_provider
  end

  def chat(messages:, context:)
    @provider.chat(messages: messages, context: context)
  end

  def stream(messages:, context:, &block)
    @provider.stream(messages: messages, context: context, &block)
  end

  private

  def default_provider
    case Rails.configuration.ai_provider
    when 'anthropic'
      Ai::Providers::AnthropicProvider.new
    when 'openai'
      Ai::Providers::OpenaiProvider.new
    else
      raise "Unknown AI provider: #{Rails.configuration.ai_provider}"
    end
  end
end
```

### GraphQL Mutation Pattern

```ruby
# app/graphql/mutations/sessions/create_session.rb
module Mutations
  module Sessions
    class CreateSession < BaseMutation
      argument :referral_source, String, required: false

      field :session, Types::OnboardingSessionType, null: false
      field :token, String, null: false

      def resolve(referral_source: nil)
        session = OnboardingSession.create!(
          status: :started,
          referral_source: referral_source,
          expires_at: 24.hours.from_now
        )

        token = Auth::JwtService.encode(session_id: session.id, role: 'anonymous')

        AuditLog.create!(
          action: 'SESSION_CREATED',
          resource: 'OnboardingSession',
          resource_id: session.id,
          ip_address: context[:ip_address]
        )

        { session: session, token: token }
      end
    end
  end
end
```

### Model with Encryption Concern

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

# app/models/parent.rb
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

### Error Handling

```ruby
# Standard error response format
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

**Error Codes:**
| Code | HTTP Equiv | Meaning |
|------|------------|---------|
| `UNAUTHENTICATED` | 401 | Invalid/missing auth |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource doesn't exist |
| `VALIDATION_ERROR` | 400 | Invalid input |
| `SESSION_EXPIRED` | 401 | Session timed out |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Unexpected error |

### Logging Strategy (PHI-Safe)

```ruby
# NEVER log PHI directly
Rails.logger.info("Session created", {
  session_id: session.id,
  # child_name: session.child.name,  # NEVER
  has_child_data: session.child.present?,  # OK
})
```

---

## Data Architecture

### Database Schema (Active Record Migrations)

```ruby
# db/migrate/001_create_onboarding_sessions.rb
class CreateOnboardingSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :onboarding_sessions, id: :uuid do |t|
      t.integer :status, default: 0, null: false
      t.jsonb :progress, default: {}
      t.datetime :expires_at, null: false
      t.string :referral_source

      t.timestamps
    end

    add_index :onboarding_sessions, :status
    add_index :onboarding_sessions, :created_at
  end
end

# db/migrate/002_create_parents.rb
class CreateParents < ActiveRecord::Migration[7.1]
  def change
    create_table :parents, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true, null: false

      # Encrypted PHI fields (Rails 7 encryption)
      t.text :email
      t.text :phone
      t.text :first_name
      t.text :last_name
      t.string :relationship
      t.boolean :is_guardian

      t.timestamps
    end

    add_index :parents, :onboarding_session_id, unique: true
  end
end

# db/migrate/003_create_children.rb
class CreateChildren < ActiveRecord::Migration[7.1]
  def change
    create_table :children, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true, null: false

      # Encrypted PHI fields
      t.text :first_name
      t.text :last_name
      t.text :date_of_birth  # Encrypted as text
      t.string :gender
      t.string :school_name
      t.string :grade

      t.timestamps
    end

    add_index :children, :onboarding_session_id, unique: true
  end
end

# db/migrate/004_create_insurances.rb
class CreateInsurances < ActiveRecord::Migration[7.1]
  def change
    create_table :insurances, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true, null: false

      t.string :payer_name
      t.text :member_id          # Encrypted
      t.text :group_number       # Encrypted
      t.text :card_image_front   # S3 key, encrypted
      t.text :card_image_back    # S3 key, encrypted

      t.integer :verification_status, default: 0
      t.jsonb :verification_result

      t.timestamps
    end

    add_index :insurances, :onboarding_session_id, unique: true
  end
end

# db/migrate/005_create_assessments.rb
class CreateAssessments < ActiveRecord::Migration[7.1]
  def change
    create_table :assessments, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true, null: false

      t.jsonb :responses, default: {}  # Encrypted via application
      t.string :risk_flags, array: true, default: []
      t.text :summary                   # Encrypted
      t.boolean :consent_given, default: false

      t.timestamps
    end

    add_index :assessments, :onboarding_session_id, unique: true
  end
end

# db/migrate/006_create_messages.rb
class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true, null: false

      t.integer :role, null: false  # user, assistant, system
      t.text :content               # Encrypted
      t.jsonb :metadata

      t.timestamps
    end

    add_index :messages, [:onboarding_session_id, :created_at]
  end
end

# db/migrate/007_create_audit_logs.rb
class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true
      t.uuid :user_id

      t.string :action, null: false
      t.string :resource, null: false
      t.uuid :resource_id
      t.jsonb :details
      t.string :ip_address
      t.string :user_agent

      t.datetime :created_at, null: false
    end

    add_index :audit_logs, :onboarding_session_id
    add_index :audit_logs, :created_at
    add_index :audit_logs, [:resource, :resource_id]
  end
end
```

### Model Enums

```ruby
# app/models/onboarding_session.rb
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

  has_one :parent, dependent: :destroy
  has_one :child, dependent: :destroy
  has_one :insurance, dependent: :destroy
  has_one :assessment, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :audit_logs, dependent: :nullify

  validates :expires_at, presence: true

  scope :active, -> { where.not(status: [:abandoned, :expired, :submitted]) }
  scope :expiring_soon, -> { active.where(expires_at: ..1.hour.from_now) }
end

# app/models/insurance.rb
class Insurance < ApplicationRecord
  include Encryptable

  enum :verification_status, {
    pending: 0,
    in_progress: 1,
    verified: 2,
    failed: 3,
    manual_review: 4,
    self_pay: 5
  }

  belongs_to :onboarding_session

  encrypts_phi :member_id, :group_number, :card_image_front, :card_image_back
end

# app/models/message.rb
class Message < ApplicationRecord
  include Encryptable

  enum :role, { user: 0, assistant: 1, system: 2 }

  belongs_to :onboarding_session

  encrypts_phi :content
end
```

---

## Security Architecture

### Authentication Flow

```
1. Parent starts onboarding
   → Anonymous session created with JWT token

2. Parent provides contact info
   → Session associated with email/phone

3. Session recovery (different device)
   → Magic link sent to email
   → Token exchanged for new JWT

4. Admin authentication
   → OAuth/OIDC via identity provider
   → JWT issued with role claims
```

### JWT Service

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

### Data Protection

| Data Type | At Rest | In Transit | Access Control |
|-----------|---------|------------|----------------|
| PHI (names, DOB) | Rails encryption | TLS 1.3 | Session owner + Admin |
| Insurance cards | S3 SSE-KMS | TLS 1.3 | Session owner only, auto-delete |
| Assessment responses | Rails encryption | TLS 1.3 | Session owner + Clinical |
| Session metadata | DB encryption | TLS 1.3 | Session owner + Admin |
| Audit logs | DB encryption | TLS 1.3 | Admin only |

---

## Background Jobs (Sidekiq)

```ruby
# app/jobs/ocr_processing_job.rb
class OcrProcessingJob < ApplicationJob
  queue_as :default
  retry_on Aws::Textract::Errors::ServiceError, wait: :exponentially_longer, attempts: 3

  def perform(insurance_id)
    insurance = Insurance.find(insurance_id)
    result = Insurance::OcrService.new(insurance).process

    insurance.update!(
      payer_name: result[:payer_name],
      member_id: result[:member_id],
      group_number: result[:group_number],
      verification_status: :pending
    )

    # Trigger eligibility check
    EligibilityCheckJob.perform_later(insurance_id)
  end
end

# config/sidekiq.yml
:concurrency: 5
:queues:
  - [critical, 3]    # Risk alerts
  - [default, 2]     # OCR, eligibility
  - [low, 1]         # Cleanup, reports
```

---

## Real-Time: GraphQL Subscriptions

```ruby
# app/channels/graphql_channel.rb
class GraphqlChannel < ApplicationCable::Channel
  def subscribed
    @subscription_ids = []
  end

  def execute(data)
    result = DaybreakHealthSchema.execute(
      data["query"],
      context: { channel: self, current_session: current_session },
      variables: data["variables"],
      operation_name: data["operationName"]
    )

    payload = { result: result.to_h, more: result.subscription? }

    @subscription_ids << result.context[:subscription_id] if result.context[:subscription_id]

    transmit(payload)
  end

  def unsubscribed
    @subscription_ids.each do |sid|
      DaybreakHealthSchema.subscriptions.delete_subscription(sid)
    end
  end
end

# app/graphql/subscriptions/message_received.rb
module Subscriptions
  class MessageReceived < BaseSubscription
    argument :session_id, ID, required: true

    field :message, Types::MessageType, null: false

    def subscribe(session_id:)
      # Verify access
      session = OnboardingSession.find(session_id)
      raise GraphQL::ExecutionError, "Unauthorized" unless authorized?(session)

      :no_response
    end

    def authorized?(session)
      context[:current_session]&.id == session.id
    end
  end
end
```

---

## Docker & Deployment

### Dockerfile

```dockerfile
# syntax=docker/dockerfile:1
FROM ruby:3.3-alpine AS base

WORKDIR /app

# Install dependencies
RUN apk add --no-cache \
    postgresql-client \
    nodejs \
    tzdata \
    libxml2 \
    libxslt

FROM base AS build

RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    libxml2-dev \
    libxslt-dev

COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

COPY . .

RUN bundle exec bootsnap precompile --gemfile app/ lib/

FROM base

COPY --from=build /app /app
COPY --from=build /usr/local/bundle /usr/local/bundle

ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=true

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### docker-compose.dev.yml

```yaml
version: '3.8'

services:
  db:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: daybreak
      POSTGRES_PASSWORD: daybreak_dev
      POSTGRES_DB: daybreak_development
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U daybreak"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  web:
    build:
      context: .
      dockerfile: docker/Dockerfile
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://daybreak:daybreak_dev@db:5432/daybreak_development
      REDIS_URL: redis://redis:6379/0
      RAILS_ENV: development
    volumes:
      - .:/app
      - bundle_cache:/usr/local/bundle

  sidekiq:
    build:
      context: .
      dockerfile: docker/Dockerfile
    command: bundle exec sidekiq
    depends_on:
      - db
      - redis
    environment:
      DATABASE_URL: postgres://daybreak:daybreak_dev@db:5432/daybreak_development
      REDIS_URL: redis://redis:6379/0

volumes:
  postgres_data:
  bundle_cache:
```

### Aptible Configuration

```yaml
# Aptfile
aptible:
  app: daybreak-health-backend
  environment: production

# Procfile
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
release: bundle exec rails db:migrate
```

---

## Development Setup

### Prerequisites

- Ruby 3.3.x (via rbenv or asdf)
- PostgreSQL 16.x (or Docker)
- Redis 7.x (or Docker)
- Docker & Docker Compose

### Setup Commands

```bash
# Clone and install
git clone <repo>
cd daybreak-health-backend
bundle install

# Environment setup
cp .env.example .env
# Edit .env with local values

# Start dependencies (Docker)
docker-compose -f docker/docker-compose.dev.yml up -d db redis

# Database setup
rails db:create db:migrate

# Run development server
rails server

# Run Sidekiq (separate terminal)
bundle exec sidekiq

# Run tests
bundle exec rspec
```

### Required Environment Variables

```bash
# .env.example
DATABASE_URL=postgres://localhost:5432/daybreak_development
REDIS_URL=redis://localhost:6379/0

# Authentication
JWT_SECRET=your-secret-key-min-32-chars
RAILS_MASTER_KEY=your-master-key

# AI Provider (choose one)
AI_PROVIDER=anthropic  # or 'openai'
ANTHROPIC_API_KEY=sk-ant-...
# OPENAI_API_KEY=sk-...

# AWS
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
S3_BUCKET=daybreak-insurance-cards

# Email
SES_SMTP_USERNAME=...
SES_SMTP_PASSWORD=...
```

---

## Architecture Decision Records (ADRs)

### ADR-001: Ruby on Rails over NestJS

**Context:** Team has Ruby/Rails expertise, need rapid development.

**Decision:** Use Rails 7 API-only mode.

**Rationale:**
- Team productivity with familiar stack
- Mature ecosystem (Sidekiq, Pundit, etc.)
- Convention over configuration
- Strong GraphQL support via graphql-ruby
- Active Record handles complex queries well

### ADR-002: Agnostic AI Provider

**Context:** Need flexibility to switch between Claude, OpenAI, or others.

**Decision:** Provider pattern with pluggable AI backends.

**Rationale:**
- Avoid vendor lock-in
- A/B testing different providers
- Fallback capability
- Cost optimization options

### ADR-003: Rails 7 Encryption for PHI

**Context:** HIPAA requires encryption of PHI at rest.

**Decision:** Use Rails 7 built-in encryption with custom concern.

**Rationale:**
- Built into framework (no extra gems)
- Handles key rotation
- Deterministic option for searchable fields
- Audit-friendly

### ADR-004: Aptible for Deployment

**Context:** Need HIPAA-compliant hosting with minimal DevOps overhead.

**Decision:** Use Aptible managed platform.

**Rationale:**
- HIPAA BAA included
- Managed PostgreSQL and Redis
- Automatic SSL/TLS
- Container-based deployment
- Built-in logging and monitoring

### ADR-005: Action Cable for Subscriptions

**Context:** Need real-time updates for AI responses and status changes.

**Decision:** Use Action Cable with Redis backend for GraphQL subscriptions.

**Rationale:**
- Built into Rails
- Works with graphql-ruby subscriptions
- Redis adapter for multi-server support
- Simpler than separate WebSocket server

---

_Generated by BMAD Architecture Workflow v6-alpha_
_Date: 2025-11-28_
_Stack: Ruby on Rails 7, PostgreSQL, GraphQL, Docker, Aptible_
