# Docker Development Environment

This document provides instructions for running the Daybreak Health Backend using Docker Compose for local development.

## Prerequisites

- Docker Desktop (version 20.10+)
- Docker Compose (version 2.0+)
- Git

## Architecture

The development environment consists of four services:

1. **PostgreSQL 16-alpine**: Primary database
2. **Redis 7-alpine**: Cache and job queue backend
3. **Web (Rails)**: Puma web server on port 3000
4. **Sidekiq**: Background job processor

## Quick Start

### 1. Clone and Setup Environment

```bash
# Clone repository
git clone <repository-url>
cd daybreak-health-backend

# Copy environment template
cp .env.example .env

# Edit .env with your local values
# Required: RAILS_MASTER_KEY (from config/master.key)
# Recommended: POSTGRES_PASSWORD (defaults to weak password if not set)
```

### 2. Start Services

```bash
# Start all services
docker-compose -f docker/docker-compose.dev.yml up -d

# Check service status
docker-compose -f docker/docker-compose.dev.yml ps

# View logs
docker-compose -f docker/docker-compose.dev.yml logs -f
```

### 3. Initialize Database

```bash
# The web service automatically runs db:prepare on startup
# To manually run migrations:
docker-compose -f docker/docker-compose.dev.yml exec web bundle exec rails db:migrate
```

### 4. Access Application

- **API Endpoint**: http://localhost:3000
- **GraphiQL IDE**: http://localhost:3000/graphiql
- **PostgreSQL**: localhost:5432
  - Database: `daybreak_health_backend_development`
  - User: `daybreak`
  - Password: Set via `POSTGRES_PASSWORD` env var (defaults to `daybreak_dev_password_change_me`)
- **Redis**: localhost:6379

## Common Commands

### Service Management

```bash
# Start services
docker-compose -f docker/docker-compose.dev.yml up -d

# Stop services
docker-compose -f docker/docker-compose.dev.yml down

# Restart a specific service
docker-compose -f docker/docker-compose.dev.yml restart web

# View service logs
docker-compose -f docker/docker-compose.dev.yml logs -f web
docker-compose -f docker/docker-compose.dev.yml logs -f sidekiq
```

### Database Operations

```bash
# Run migrations
docker-compose -f docker/docker-compose.dev.yml exec web bundle exec rails db:migrate

# Rollback migration
docker-compose -f docker/docker-compose.dev.yml exec web bundle exec rails db:rollback

# Seed database
docker-compose -f docker/docker-compose.dev.yml exec web bundle exec rails db:seed

# Open Rails console
docker-compose -f docker/docker-compose.dev.yml exec web bundle exec rails console

# Reset database (WARNING: destroys all data)
docker-compose -f docker/docker-compose.dev.yml exec web bundle exec rails db:reset
```

### Testing

```bash
# Run RSpec tests
docker-compose -f docker/docker-compose.dev.yml exec web bundle exec rspec

# Run specific test file
docker-compose -f docker/docker-compose.dev.yml exec web bundle exec rspec spec/models/onboarding_session_spec.rb

# Run RuboCop linter
docker-compose -f docker/docker-compose.dev.yml exec web bundle exec rubocop
```

### Debugging

```bash
# Attach to running web container (for pry/byebug)
docker attach daybreak-web

# Execute shell in web container
docker-compose -f docker/docker-compose.dev.yml exec web sh

# View Sidekiq jobs
docker-compose -f docker/docker-compose.dev.yml exec web bundle exec rails runner "puts Sidekiq::Queue.all.map(&:name)"
```

## Environment Variables

Required environment variables (set in `.env`):

| Variable | Description | Example |
|----------|-------------|---------|
| `RAILS_MASTER_KEY` | Rails credentials master key | `<32-char-key>` |
| `POSTGRES_PASSWORD` | PostgreSQL database password | `your_secure_password` |
| `DATABASE_URL` | PostgreSQL connection string (optional, auto-built from POSTGRES_PASSWORD) | `postgresql://daybreak:password@db:5432/daybreak_health_backend_development` |
| `REDIS_URL` | Redis connection string | `redis://redis:6379/0` |

Optional environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `RAILS_ENV` | Rails environment | `development` |
| `RAILS_MAX_THREADS` | Puma threads per worker | `5` |

## Health Checks

Services include health checks for proper orchestration:

**PostgreSQL:**
- Command: `pg_isready -U daybreak`
- Interval: 10 seconds
- Retries: 5

**Redis:**
- Command: `redis-cli ping`
- Interval: 10 seconds
- Retries: 5

The web and sidekiq services wait for database and Redis to be healthy before starting.

## Data Persistence

Data is persisted in named Docker volumes:

- `postgres_data`: PostgreSQL database files
- `redis_data`: Redis persistence
- `bundle_cache`: Bundler gem cache (speeds up rebuilds)
- `rails_cache`: Rails tmp/cache directory

To remove all data and start fresh:

```bash
docker-compose -f docker/docker-compose.dev.yml down -v
```

## Troubleshooting

### Services Won't Start

**Problem**: Services fail health checks or won't start.

**Solutions**:
1. Check Docker Desktop is running
2. Ensure ports 3000, 5432, 6379 are not in use:
   ```bash
   lsof -i :3000
   lsof -i :5432
   lsof -i :6379
   ```
3. View service logs:
   ```bash
   docker-compose -f docker/docker-compose.dev.yml logs db
   docker-compose -f docker/docker-compose.dev.yml logs redis
   ```

### Database Connection Errors

**Problem**: Rails can't connect to PostgreSQL.

**Solutions**:
1. Verify database service is healthy:
   ```bash
   docker-compose -f docker/docker-compose.dev.yml ps db
   ```
2. Check DATABASE_URL is correct in .env
3. Restart web service:
   ```bash
   docker-compose -f docker/docker-compose.dev.yml restart web
   ```

### Redis Connection Errors

**Problem**: Rails can't connect to Redis.

**Solutions**:
1. Verify Redis service is healthy:
   ```bash
   docker-compose -f docker/docker-compose.dev.yml ps redis
   ```
2. Test Redis connection manually:
   ```bash
   docker-compose -f docker/docker-compose.dev.yml exec redis redis-cli ping
   ```

### Bundle Install Errors

**Problem**: Gem installation fails or is slow.

**Solutions**:
1. Rebuild with no cache:
   ```bash
   docker-compose -f docker/docker-compose.dev.yml build --no-cache web
   ```
2. Clear bundle cache volume:
   ```bash
   docker volume rm daybreak-health-backend_bundle_cache
   ```

### Permission Errors

**Problem**: Permission denied errors on volumes.

**Solutions**:
1. The Dockerfile creates a non-root user (rails:1000)
2. Ensure local files aren't owned by root:
   ```bash
   sudo chown -R $USER:$USER .
   ```

### Slow Performance on macOS

**Problem**: File sync is slow (especially on macOS).

**Solutions**:
1. Use Docker Desktop's VirtioFS (Settings > General > VirtioFS)
2. Consider limiting volume mounts to only necessary directories
3. Use native Rails server for development instead of Docker

## Production Build

To build the production Docker image:

```bash
# Build image
docker build -f docker/Dockerfile -t daybreak-health-backend:latest .

# Run production container (requires environment variables)
docker run -d \
  -p 3000:3000 \
  -e RAILS_MASTER_KEY=<key> \
  -e DATABASE_URL=<url> \
  -e REDIS_URL=<url> \
  daybreak-health-backend:latest
```

## Aptible Deployment

This application is configured for deployment to Aptible.

### Prerequisites

1. Install Aptible CLI:
   ```bash
   brew install aptible/tap/aptible
   ```

2. Login to Aptible:
   ```bash
   aptible login
   ```

### First-Time Setup

```bash
# Create app
aptible apps:create daybreak-health-backend

# Create PostgreSQL database
aptible db:create daybreak-db --type postgresql --version 16

# Create Redis database
aptible db:create daybreak-redis --type redis --version 7.0

# Set environment variables
aptible config:set --app daybreak-health-backend \
  RAILS_MASTER_KEY=<your-master-key> \
  RAILS_ENV=production

# Add git remote
git remote add aptible git@beta.aptible.com:daybreak-health-backend/daybreak-health-backend.git
```

### Deployment

```bash
# Deploy to Aptible
git push aptible main

# Run migrations (happens automatically via release process in Procfile)
# Manual run if needed:
aptible run --app daybreak-health-backend -- bundle exec rails db:migrate

# View logs
aptible logs --app daybreak-health-backend

# Scale worker process
aptible ps:scale --app daybreak-health-backend worker=1
```

### Aptible Resources

- **Procfile**: Defines web, worker, and release processes
- **Aptfile**: Specifies PostgreSQL 16 dependency
- **Dockerfile**: Multi-stage build optimized for production

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Rails Docker Guide](https://guides.rubyonrails.org/getting_started_with_engines.html#using-docker)
- [Aptible Documentation](https://www.aptible.com/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/16/)
- [Redis Documentation](https://redis.io/docs/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review service logs
3. Consult the project README.md
4. Contact the development team
