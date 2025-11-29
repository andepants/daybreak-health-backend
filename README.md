# Daybreak Health Backend

AI-powered mental health onboarding and intake system for matching families with appropriate care providers.

## Overview

The Daybreak Health Backend is a HIPAA-compliant Rails API that powers an intelligent onboarding flow for mental health services. It uses conversational AI to guide parents through collecting child information, insurance details, and mental health assessments, then matches families with appropriate care providers based on clinical needs and insurance coverage.

### Key Features

- **AI-Powered Conversational Onboarding**: Uses Claude (Anthropic) or GPT-4 to have natural conversations with parents while collecting structured intake data
- **Session Management**: Robust session lifecycle with expiration, recovery, multi-device support, and automated cleanup
- **Data Security**: End-to-end encryption for PHI (Protected Health Information), HIPAA-compliant audit logging
- **GraphQL API**: Modern, flexible API for web and mobile clients
- **Background Job Processing**: Sidekiq-based job queue with scheduled tasks for session cleanup and retention compliance
- **Provider Matching**: Intelligent matching algorithm considering clinical needs, insurance networks, availability, and specialty

## Technology Stack

- **Ruby**: 3.2.0 (3.3.x recommended)
- **Rails**: 7.2.3
- **Database**: PostgreSQL 16.x
- **API**: GraphQL (graphql-ruby ~> 2.2)
- **Background Jobs**: Sidekiq 7.2 with sidekiq-cron for scheduled tasks
- **Cache/Queue**: Redis 7.x
- **AI Providers**: Anthropic Claude API, OpenAI GPT-4 (configurable)
- **Testing**: RSpec 6.1, FactoryBot
- **Security**: JWT authentication, bcrypt password hashing, Pundit authorization

## Quick Start

See [SETUP.md](SETUP.md) for detailed installation instructions.

```bash
# Install dependencies
bundle install

# Configure environment
cp .env.example .env
# Edit .env with your API keys and database credentials

# Setup database
rails db:create db:migrate

# Run tests
bundle exec rspec

# Start services (requires 2 terminal windows)
rails server                  # Terminal 1: Rails API server
bundle exec sidekiq          # Terminal 2: Background jobs
```

**Access Points:**
- API: http://localhost:3000
- GraphiQL IDE: http://localhost:3000/graphiql
- Sidekiq Dashboard: http://localhost:3000/sidekiq
- Health Check: http://localhost:3000/health

## Session Management

The system implements a sophisticated session lifecycle with automated management:

### Session States

Sessions progress through these states:
```
STARTED → IN_PROGRESS → INSURANCE_PENDING → ASSESSMENT_COMPLETE → SUBMITTED
              ↓               ↓                     ↓                   ↓
         ABANDONED       ABANDONED             ABANDONED          ABANDONED
              ↓               ↓                     ↓                   ↓
          EXPIRED         EXPIRED               EXPIRED             EXPIRED
```

### Automated Session Cleanup

**SessionCleanupJob** (Every 15 minutes)
- Automatically marks sessions as `EXPIRED` after 24 hours of inactivity
- Creates audit trail for compliance
- Prevents further updates to expired sessions

**SessionRetentionCleanupJob** (Weekly)
- Permanently deletes expired sessions after 90-day retention period
- Ensures HIPAA compliance for data retention policies
- Cascades deletion to all associated data (messages, assessments, etc.)

### Environment Variables

Key configuration options:

```bash
# Session expiration (hours since last activity)
SESSION_EXPIRATION_HOURS=24

# Data retention period (days to keep expired sessions)
DATA_RETENTION_DAYS=90

# AI Provider Configuration
ANTHROPIC_API_KEY=your_key_here
OPENAI_API_KEY=your_key_here     # Optional fallback

# JWT Authentication
JWT_SECRET_KEY=generate_with_rails_secret

# Database
DATABASE_URL=postgresql://localhost/daybreak_health_backend_development
```

See `.env.example` for complete list of configuration options.

## Architecture

### Core Modules

- **Session Management** (`app/models/onboarding_session.rb`): Session lifecycle, state machine, expiration logic
- **AI Conversation** (`lib/ai_providers/`): Conversational AI integration with Claude/GPT-4
- **Data Encryption** (`lib/encryption/`): PHI encryption for HIPAA compliance
- **GraphQL API** (`app/graphql/`): Schema, types, mutations, queries
- **Background Jobs** (`app/jobs/`): Session cleanup, retention, matching
- **Authorization** (`app/policies/`): Pundit-based access control

### Data Models

- **OnboardingSession**: Core session entity with state machine
- **Parent**: Parent/guardian information (encrypted PHI)
- **Child**: Child information and demographics (encrypted PHI)
- **Insurance**: Insurance coverage details (encrypted PHI)
- **Assessment**: Mental health assessment responses (encrypted PHI)
- **Message**: Conversational AI message history
- **AuditLog**: Comprehensive audit trail for compliance
- **RefreshToken**: JWT refresh token management

### Security & Compliance

- **Encryption**: All PHI encrypted at rest using AES-256-GCM
- **Audit Logging**: Every data access and modification logged with timestamps, user context, and actions
- **Session Security**: Secure token-based authentication with refresh tokens
- **HIPAA Compliance**: 90-day data retention, encrypted storage, comprehensive audit trails
- **Authorization**: Role-based access control via Pundit policies

## Development

### Running Tests

```bash
# Run full test suite
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/onboarding_session_spec.rb

# Run tests with coverage
COVERAGE=true bundle exec rspec
```

### Code Quality

```bash
# Run linter
bundle exec rubocop

# Auto-fix linting issues
bundle exec rubocop -a

# Check security vulnerabilities
bundle audit
```

### Rails Console

```bash
# Development console
rails console

# Useful commands in console
OnboardingSession.count
SessionCleanupJob.perform_now
Sidekiq::Cron::Job.all
```

## API Documentation

GraphQL schema is accessible via GraphiQL at http://localhost:3000/graphiql

### Key Mutations

- `createAnonymousSession`: Start new onboarding session
- `updateSessionProgress`: Update session state and data
- `abandonSession`: Mark session as abandoned
- `recoverSession`: Resume existing session on new device

### Key Queries

- `onboardingSession(id: ID!)`: Retrieve session details
- `healthCheck`: API health status

See `app/graphql/schema.graphql` for complete schema documentation.

## Background Jobs

### Scheduled Jobs (Sidekiq-cron)

| Job | Schedule | Purpose |
|-----|----------|---------|
| SessionCleanupJob | Every 15 minutes | Mark expired sessions |
| SessionRetentionCleanupJob | Weekly (Sunday 2 AM) | Delete old expired sessions |

View scheduled jobs: http://localhost:3000/sidekiq/cron

## Project Structure

```
daybreak-health-backend/
├── app/
│   ├── controllers/         # API controllers (health check)
│   ├── graphql/            # GraphQL schema, types, mutations
│   │   ├── mutations/      # GraphQL mutations
│   │   ├── types/          # GraphQL types
│   │   └── errors/         # Error codes and handling
│   ├── jobs/               # Sidekiq background jobs
│   ├── models/             # Active Record models
│   ├── policies/           # Pundit authorization policies
│   └── services/           # Business logic service objects
├── config/
│   ├── initializers/       # Rails initializers (Sidekiq-cron, etc.)
│   └── routes.rb           # Application routes
├── db/
│   ├── migrate/            # Database migrations
│   └── schema.rb           # Database schema
├── lib/
│   ├── ai_providers/       # AI provider integrations
│   └── encryption/         # Data encryption utilities
├── spec/                   # RSpec tests
│   ├── factories/          # FactoryBot test data
│   ├── models/             # Model tests
│   ├── graphql/            # GraphQL tests
│   ├── jobs/               # Job tests
│   └── services/           # Service tests
└── docs/                   # Project documentation
    ├── architecture.md     # Architecture documentation
    ├── epics.md           # Epic and story definitions
    └── sprint-artifacts/   # Sprint planning and stories
```

## Contributing

This project follows the BMad (Build-Measure-Adapt) methodology with AI-assisted development.

### Development Workflow

1. Review epic and story documentation in `docs/sprint-artifacts/`
2. Implement features according to acceptance criteria
3. Write comprehensive RSpec tests (TDD approach)
4. Update relevant documentation
5. Run full test suite and linter before committing
6. Code review process documented in story files

### Testing Standards

- **Minimum Coverage**: 90% code coverage required
- **Test Types**: Unit, integration, and GraphQL tests
- **CI/CD**: All tests must pass before merge
- **Factories**: Use FactoryBot for test data

## Support & Documentation

- **Setup Guide**: [SETUP.md](SETUP.md)
- **Architecture**: `docs/architecture.md`
- **Epic Breakdown**: `docs/epics.md`
- **Sprint Artifacts**: `docs/sprint-artifacts/`
- **Docker Setup**: [DOCKER.md](DOCKER.md) (if using Docker)

## License

Proprietary - Daybreak Health

## Contact

For questions or issues, refer to project documentation in the `docs/` directory.
