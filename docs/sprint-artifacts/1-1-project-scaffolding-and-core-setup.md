# Story 1.1: Project Scaffolding & Core Setup

Status: ready-for-dev

## Story

As a developer,
I want a properly configured Rails 7 API project with GraphQL,
so that I have a consistent foundation for building all features.

## Acceptance Criteria

1. **AC 1.1.1**: Rails 7.x project created in API-only mode with PostgreSQL
2. **AC 1.1.2**: GraphQL configured via graphql-ruby gem
3. **AC 1.1.3**: Project structure matches Architecture document (app/graphql/, app/services/, app/policies/, app/jobs/)
4. **AC 1.1.4**: RuboCop configured with project conventions
5. **AC 1.1.5**: .env.example created with all required environment variables
6. **AC 1.1.6**: rails server starts on port 3000
7. **AC 1.1.7**: GraphiQL accessible at /graphiql in development

## Tasks / Subtasks

- [ ] **Task 1**: Initialize Rails 7 API project (AC: 1.1.1)
  - [ ] Subtask 1.1: Execute `rails new daybreak-health-backend --api --database=postgresql --skip-test`
  - [ ] Subtask 1.2: Verify Rails 7.x version in Gemfile
  - [ ] Subtask 1.3: Configure database.yml for PostgreSQL
  - [ ] Subtask 1.4: Run `bundle install`

- [ ] **Task 2**: Add required gems (AC: 1.1.2, 1.1.5)
  - [ ] Subtask 2.1: Add graphql gem to Gemfile
  - [ ] Subtask 2.2: Add sidekiq gem for background jobs
  - [ ] Subtask 2.3: Add redis gem for caching/sessions
  - [ ] Subtask 2.4: Add jwt gem for authentication tokens
  - [ ] Subtask 2.5: Add bcrypt gem for password hashing
  - [ ] Subtask 2.6: Add pundit gem for authorization
  - [ ] Subtask 2.7: Add rspec-rails to development/test group
  - [ ] Subtask 2.8: Add rubocop and rubocop-rails to development group
  - [ ] Subtask 2.9: Run `bundle install`

- [ ] **Task 3**: Run GraphQL generator (AC: 1.1.2)
  - [ ] Subtask 3.1: Execute `rails generate graphql:install`
  - [ ] Subtask 3.2: Verify app/graphql/ directory structure created
  - [ ] Subtask 3.3: Verify GraphQL route added to routes.rb
  - [ ] Subtask 3.4: Configure GraphiQL for development environment

- [ ] **Task 4**: Create project directory structure per architecture (AC: 1.1.3)
  - [ ] Subtask 4.1: Create app/services/ directory
  - [ ] Subtask 4.2: Create app/services/base_service.rb template
  - [ ] Subtask 4.3: Create app/policies/ directory
  - [ ] Subtask 4.4: Create app/policies/application_policy.rb
  - [ ] Subtask 4.5: Create app/jobs/ directory (if not exists)
  - [ ] Subtask 4.6: Create lib/encryption/ directory
  - [ ] Subtask 4.7: Create lib/ai_providers/ directory
  - [ ] Subtask 4.8: Verify app/graphql/ structure matches architecture

- [ ] **Task 5**: Configure RuboCop (AC: 1.1.4)
  - [ ] Subtask 5.1: Create .rubocop.yml with project conventions
  - [ ] Subtask 5.2: Configure snake_case for files
  - [ ] Subtask 5.3: Configure PascalCase for classes
  - [ ] Subtask 5.4: Set up Rails-specific cops
  - [ ] Subtask 5.5: Run `rubocop --auto-gen-config`
  - [ ] Subtask 5.6: Run `rubocop -a` to auto-correct issues

- [ ] **Task 6**: Create .env.example (AC: 1.1.5)
  - [ ] Subtask 6.1: Create .env.example file
  - [ ] Subtask 6.2: Add DATABASE_URL template
  - [ ] Subtask 6.3: Add REDIS_URL template
  - [ ] Subtask 6.4: Add JWT_SECRET_KEY placeholder
  - [ ] Subtask 6.5: Add OPENAI_API_KEY placeholder
  - [ ] Subtask 6.6: Add ANTHROPIC_API_KEY placeholder
  - [ ] Subtask 6.7: Add ENCRYPTION_KEY placeholder
  - [ ] Subtask 6.8: Add RAILS_ENV and PORT variables
  - [ ] Subtask 6.9: Add .env to .gitignore

- [ ] **Task 7**: Configure CORS
  - [ ] Subtask 7.1: Uncomment rack-cors gem in Gemfile
  - [ ] Subtask 7.2: Configure CORS in config/initializers/cors.rb
  - [ ] Subtask 7.3: Set appropriate origins for development/production
  - [ ] Subtask 7.4: Run `bundle install`

- [ ] **Task 8**: Add health check endpoint (AC: 1.1.6)
  - [ ] Subtask 8.1: Create app/controllers/health_controller.rb
  - [ ] Subtask 8.2: Add health#check action
  - [ ] Subtask 8.3: Add route GET /health to routes.rb
  - [ ] Subtask 8.4: Test health endpoint responds with 200 OK

- [ ] **Task 9**: Configure initializers
  - [ ] Subtask 9.1: Create config/initializers/encryption.rb stub
  - [ ] Subtask 9.2: Create config/initializers/ai_providers.rb stub
  - [ ] Subtask 9.3: Create config/initializers/sidekiq.rb
  - [ ] Subtask 9.4: Create config/initializers/redis.rb

- [ ] **Task 10**: Write RSpec tests for setup verification
  - [ ] Subtask 10.1: Initialize RSpec with `rails generate rspec:install`
  - [ ] Subtask 10.2: Create spec/requests/health_spec.rb
  - [ ] Subtask 10.3: Create spec/graphql/schema_spec.rb
  - [ ] Subtask 10.4: Test GraphQL schema loads without errors
  - [ ] Subtask 10.5: Test all required directories exist
  - [ ] Subtask 10.6: Run `bundle exec rspec` and verify all tests pass

- [ ] **Task 11**: Final verification (AC: 1.1.6, 1.1.7)
  - [ ] Subtask 11.1: Create development database with `rails db:create`
  - [ ] Subtask 11.2: Start Rails server with `rails server`
  - [ ] Subtask 11.3: Verify server starts on port 3000
  - [ ] Subtask 11.4: Access http://localhost:3000/health
  - [ ] Subtask 11.5: Access http://localhost:3000/graphiql
  - [ ] Subtask 11.6: Verify GraphiQL interface loads
  - [ ] Subtask 11.7: Run introspection query in GraphiQL

## Dev Notes

### Architecture Patterns and Constraints

- **API-Only Mode**: Rails configured without views, helpers, or assets
- **GraphQL First**: All client interactions through GraphQL API
- **Service Objects**: Business logic encapsulated in app/services/
- **Authorization**: Pundit policies in app/policies/
- **Background Jobs**: Sidekiq for asynchronous processing
- **Naming Conventions**:
  - Files: snake_case (e.g., user_service.rb)
  - Classes: PascalCase (e.g., UserService)
  - Modules: PascalCase (e.g., AiProviders)

### Source Tree Components to Touch

```
daybreak-health-backend/
├── app/
│   ├── controllers/
│   │   └── health_controller.rb (create)
│   ├── graphql/
│   │   ├── types/
│   │   ├── mutations/
│   │   └── daybreak_health_backend_schema.rb (generated)
│   ├── services/
│   │   └── base_service.rb (create)
│   ├── policies/
│   │   └── application_policy.rb (create)
│   └── jobs/
├── config/
│   ├── initializers/
│   │   ├── cors.rb (modify)
│   │   ├── encryption.rb (create)
│   │   ├── ai_providers.rb (create)
│   │   ├── sidekiq.rb (create)
│   │   └── redis.rb (create)
│   ├── routes.rb (modify)
│   └── database.yml (verify)
├── lib/
│   ├── encryption/ (create directory)
│   └── ai_providers/ (create directory)
├── spec/
│   ├── requests/
│   │   └── health_spec.rb (create)
│   └── graphql/
│       └── schema_spec.rb (create)
├── Gemfile (modify)
├── .rubocop.yml (create)
├── .env.example (create)
└── .gitignore (modify)
```

### Testing Standards Summary

- **Framework**: RSpec for all testing
- **Coverage**: Request specs for API endpoints, unit specs for services
- **GraphQL Testing**: Schema validation and query/mutation specs
- **Integration**: Health check and GraphiQL accessibility
- **CI Ready**: All specs must pass before story completion

### Project Structure Notes

#### Alignment with Unified Project Structure

This story establishes the foundation matching the Architecture document:

**Core Directories**:
- `app/graphql/` - GraphQL schema, types, mutations, queries
- `app/services/` - Business logic layer (BaseService pattern)
- `app/policies/` - Authorization logic (Pundit)
- `app/jobs/` - Background processing (Sidekiq)
- `lib/encryption/` - Data encryption utilities
- `lib/ai_providers/` - OpenAI and Anthropic integrations

**Configuration**:
- Environment-based settings via .env
- Initializers for cross-cutting concerns
- CORS for frontend integration
- Redis for caching and Sidekiq

**Testing Structure**:
- `spec/requests/` - API endpoint tests
- `spec/graphql/` - GraphQL schema and resolver tests
- `spec/services/` - Business logic tests
- `spec/policies/` - Authorization tests

### References

- [Source: docs/architecture.md#Project Structure]
- [Source: docs/architecture.md#Technology Stack]
- [Source: docs/architecture.md#Development Standards]
- [Source: docs/tech-spec.md#Epic 1: Foundation & Infrastructure]
- [Source: docs/epics.md#Epic 1: Core Infrastructure & Authentication]

## Dev Agent Record

### Context Reference
docs/sprint-artifacts/1-1-project-scaffolding-and-core-setup.context.xml

### Agent Model Used
<!-- Will be populated during implementation -->
<!-- Example: claude-sonnet-4-5-20250929 -->

### Debug Log References
<!-- Links to debug logs if issues encountered -->

### Completion Notes List
<!-- Notes added during implementation:
- Challenges encountered
- Decisions made
- Deviations from plan
- Performance observations
-->

### File List
<!-- Complete list of files created/modified during implementation -->
