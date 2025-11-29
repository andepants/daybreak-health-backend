# Story 1.4: Docker & Local Development Environment

Status: ready-for-dev

## Story

As a developer,
I want Docker Compose configuration for local development,
so that I can run PostgreSQL and Redis locally without manual setup.

## Acceptance Criteria

1. **AC 1.4.1**: docker-compose.dev.yml defines PostgreSQL 16.x and Redis 7.x services
2. **AC 1.4.2**: PostgreSQL exposed on port 5432 with persistent volume
3. **AC 1.4.3**: Redis exposed on port 6379
4. **AC 1.4.4**: Health checks configured for both services
5. **AC 1.4.5**: Dockerfile created for production builds (multi-stage, Ruby 3.3-alpine)
6. **AC 1.4.6**: .dockerignore excludes vendor/bundle, .env, tmp/, log/
7. **AC 1.4.7**: docker-compose up -d starts dependencies
8. **AC 1.4.8**: Application connects successfully to both services
9. **AC 1.4.9**: Sidekiq container configured for background job processing
10. **AC 1.4.10**: Aptible configuration present (Aptfile and Procfile)

## Tasks / Subtasks

- [ ] **Task 1**: Create docker-compose.dev.yml with database and Redis services (AC: 1.4.1, 1.4.2, 1.4.3)
  - [ ] 1.1: Define PostgreSQL 16-alpine service with port 5432
  - [ ] 1.2: Configure persistent volume for PostgreSQL data
  - [ ] 1.3: Define Redis 7-alpine service with port 6379
  - [ ] 1.4: Configure volume for bundle caching

- [ ] **Task 2**: Add health check configurations (AC: 1.4.4)
  - [ ] 2.1: Implement PostgreSQL health check using pg_isready
  - [ ] 2.2: Implement Redis health check using redis-cli ping
  - [ ] 2.3: Configure health check intervals and retries

- [ ] **Task 3**: Create multi-stage production Dockerfile (AC: 1.4.5)
  - [ ] 3.1: Define builder stage with Ruby 3.3-alpine
  - [ ] 3.2: Install build dependencies and gems
  - [ ] 3.3: Define runtime stage with minimal dependencies
  - [ ] 3.4: Configure bootsnap precompilation
  - [ ] 3.5: Set proper working directory and user permissions

- [ ] **Task 4**: Create .dockerignore file (AC: 1.4.6)
  - [ ] 4.1: Exclude vendor/bundle directory
  - [ ] 4.2: Exclude .env files
  - [ ] 4.3: Exclude tmp/ and log/ directories
  - [ ] 4.4: Exclude development and test artifacts

- [ ] **Task 5**: Add web service to docker-compose (AC: 1.4.7, 1.4.8)
  - [ ] 5.1: Define web service using Dockerfile
  - [ ] 5.2: Configure environment variables for database and Redis
  - [ ] 5.3: Set up depends_on with service_healthy conditions
  - [ ] 5.4: Mount source code volume for development
  - [ ] 5.5: Expose port 3000 for Rails server

- [ ] **Task 6**: Add Sidekiq service to docker-compose (AC: 1.4.9)
  - [ ] 6.1: Define sidekiq service using same Dockerfile as web
  - [ ] 6.2: Override command to run Sidekiq worker
  - [ ] 6.3: Configure Redis connection
  - [ ] 6.4: Set up depends_on for database and Redis

- [ ] **Task 7**: Create Aptible deployment configuration (AC: 1.4.10)
  - [ ] 7.1: Create Procfile with web and worker processes
  - [ ] 7.2: Create Aptfile with PostgreSQL 16 specification
  - [ ] 7.3: Document Aptible deployment requirements

- [ ] **Task 8**: Integration testing (AC: 1.4.7, 1.4.8)
  - [ ] 8.1: Test docker-compose up -d starts all services
  - [ ] 8.2: Verify PostgreSQL connection from Rails
  - [ ] 8.3: Verify Redis connection from Rails
  - [ ] 8.4: Verify Sidekiq can process jobs
  - [ ] 8.5: Test docker-compose down cleanup

- [ ] **Task 9**: Create development setup documentation
  - [ ] 9.1: Document docker-compose commands
  - [ ] 9.2: Document environment variable requirements
  - [ ] 9.3: Document troubleshooting steps
  - [ ] 9.4: Document Aptible deployment process

## Dev Notes

### Architecture Patterns and Constraints

- **Container Strategy**: Use official Alpine-based images for minimal footprint
- **Multi-stage Builds**: Separate build and runtime stages to reduce production image size
- **Health Checks**: Required for proper service orchestration and deployment readiness
- **Volume Mounting**: Development mode uses bind mounts; production uses named volumes
- **Service Dependencies**: Web and Sidekiq services depend on healthy database and Redis
- **Environment Parity**: Docker configuration should mirror Aptible production environment

### Source Tree Components

```
/Users/andre/coding/daybreak/daybreak-health-backend/
├── docker/
│   ├── Dockerfile                    # Multi-stage production build
│   └── docker-compose.dev.yml        # Local development services
├── .dockerignore                      # Docker build exclusions
├── Procfile                          # Aptible process definitions
├── Aptfile                           # Aptible dependencies
└── config/
    ├── database.yml                  # PostgreSQL configuration
    └── initializers/
        ├── redis.rb                  # Redis connection setup
        └── sidekiq.rb                # Sidekiq configuration
```

### Testing Standards Summary

- **Service Health**: All services must pass health checks before accepting connections
- **Connection Tests**: Rails console must successfully connect to PostgreSQL and Redis
- **Job Processing**: Sidekiq must successfully enqueue and process test jobs
- **Startup Time**: Services should be healthy within 30 seconds of startup
- **Cleanup**: docker-compose down should cleanly stop all services without errors

### Project Structure Notes

**Alignment with Unified Project Structure:**

- Docker configurations follow containerization best practices
- Separation of development (docker-compose.dev.yml) and production (Dockerfile) concerns
- Configuration files placed at project root per Rails conventions
- Environment-specific settings managed through Docker Compose environment variables
- Aptible configuration files at root for platform-as-a-service deployment
- Health checks enable zero-downtime deployments on Aptible

**Key Dependencies:**
- PostgreSQL 16.x (official postgres:16-alpine image)
- Redis 7.x (official redis:7-alpine image)
- Ruby 3.3-alpine base image for production
- Aptible CLI for deployment management

**Security Considerations:**
- Database credentials managed via environment variables
- No sensitive data in Docker images or compose files
- .dockerignore prevents credential leakage
- Production images run as non-root user

### References

- [Source: docs/epic-1-tech-spec.md#Story 1.4: Docker & Local Development Environment]
- [Source: docs/epic-1-tech-spec.md#Implementation Notes]
- [Source: docs/epics.md#Story 1.4: Docker & Local Development Environment]

## Dev Agent Record

### Context Reference
docs/sprint-artifacts/1-4-docker-and-local-development-environment.context.xml

### Agent Model Used
<!-- To be filled during implementation: claude-sonnet-4-5-20250929 or equivalent -->

### Debug Log References
<!-- To be added during implementation -->

### Completion Notes List
<!-- To be added during implementation:
- Service startup times
- Health check validation results
- Connection test outcomes
- Any deviations from planned configuration
- Performance observations
-->

### File List
<!-- To be populated during implementation:
- docker/Dockerfile
- docker/docker-compose.dev.yml
- .dockerignore
- Procfile
- Aptfile
- config/database.yml (if modified)
- config/initializers/redis.rb (if created)
- config/initializers/sidekiq.rb (if created)
-->
