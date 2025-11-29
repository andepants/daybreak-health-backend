# Daybreak Health Backend - Setup Instructions

## Prerequisites

Before you can run this application, you need to install:

1. **Ruby 3.3.x** (currently using 3.2.0, recommend upgrade)
   ```bash
   # Using rbenv
   rbenv install 3.3.0
   rbenv local 3.3.0

   # Or using RVM
   rvm install 3.3.0
   rvm use 3.3.0
   ```

2. **PostgreSQL 16.x**
   ```bash
   # macOS (using Homebrew)
   brew install postgresql@16
   brew services start postgresql@16

   # Ubuntu/Debian
   sudo apt-get install postgresql-16

   # Verify installation
   psql --version
   ```

3. **Redis 7.x** (optional for now, required for Sidekiq later)
   ```bash
   # macOS
   brew install redis
   brew services start redis

   # Ubuntu/Debian
   sudo apt-get install redis-server

   # Verify installation
   redis-cli ping  # Should return PONG
   ```

## Installation Steps

### 1. Clone and Install Dependencies

```bash
cd /Users/andre/coding/daybreak/daybreak-health-backend
bundle install
```

### 2. Configure Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env and update the following variables:
# - DATABASE_URL (if using non-default PostgreSQL setup)
# - JWT_SECRET_KEY (generate with: rails secret)
# - ANTHROPIC_API_KEY (your Claude API key)
# - OPENAI_API_KEY (your OpenAI API key, optional)
```

### 3. Create Database

```bash
# Create the development and test databases
rails db:create

# Run migrations (when available in later stories)
rails db:migrate
```

### 4. Enable Development Caching

The application uses Redis caching for session data. Enable caching in development:

```bash
# Enable caching in development environment
rails dev:cache

# Verify caching is enabled (should see "Caching enabled")
```

This creates a `tmp/caching-dev.txt` file that enables Redis cache store. To disable caching later:

```bash
# Disable caching (toggles the state)
rails dev:cache
```

**Note:** Redis caching is required for session progress updates and multi-device sync features.

### 5. Start the Development Server

```bash
# Start Rails server on port 3000
rails server

# Or use the shorthand
rails s
```

The server should start successfully and be accessible at:
- API endpoint: http://localhost:3000
- Health check: http://localhost:3000/health
- GraphiQL IDE: http://localhost:3000/graphiql

### 6. Verify Installation

Run the test suite to verify everything is working:

```bash
bundle exec rspec
```

Expected output: `24 examples, 0 failures`

## Required: Start Background Jobs (Epic 2+)

Starting with Epic 2 (Session Lifecycle & Authentication), background jobs are **required** for session management features including session expiration and cleanup.

### Starting Sidekiq with Cron Jobs

```bash
# In a separate terminal window
bundle exec sidekiq
```

Sidekiq will automatically load scheduled cron jobs from `config/initializers/sidekiq_cron.rb`.

### Verifying Scheduled Jobs

You can verify that cron jobs are properly scheduled:

**Via Rails Console:**
```bash
rails console

# List all scheduled cron jobs
Sidekiq::Cron::Job.all

# Check specific job
Sidekiq::Cron::Job.find('session_cleanup')
Sidekiq::Cron::Job.find('session_retention_cleanup')
```

**Via Sidekiq Web UI:**

1. Mount Sidekiq Web UI in `config/routes.rb` (add if not present):
   ```ruby
   require 'sidekiq/web'
   require 'sidekiq/cron/web'

   Rails.application.routes.draw do
     mount Sidekiq::Web => '/sidekiq'
   end
   ```

2. Visit http://localhost:3000/sidekiq/cron to see all scheduled jobs

3. You should see:
   - **session_cleanup**: Runs every 15 minutes (`*/15 * * * *`)
   - **session_retention_cleanup**: Runs weekly on Sunday at 2 AM (`0 2 * * 0`)

### Scheduled Job Details

**SessionCleanupJob** (Every 15 minutes)
- Marks expired sessions (where `expires_at` has passed) as `EXPIRED`
- Creates audit logs for each expired session
- Required for AC 2.4.1, 2.4.5

**SessionRetentionCleanupJob** (Weekly)
- Permanently deletes expired sessions after 90-day retention period
- Cascades deletion to associated data (messages, progress, etc.)
- Creates audit logs before deletion
- Required for AC 2.4.2, 2.4.3

### Troubleshooting Background Jobs

**Jobs not appearing in Sidekiq-cron:**
```bash
# Check if sidekiq-cron gem is installed
bundle list | grep sidekiq-cron

# Restart Sidekiq after configuration changes
pkill -f sidekiq
bundle exec sidekiq
```

**Manually trigger a job for testing:**
```bash
rails console

# Execute job immediately (bypasses queue)
SessionCleanupJob.perform_now

# Enqueue job (goes through Sidekiq)
SessionCleanupJob.perform_later
```

**Check job execution logs:**
```bash
# Sidekiq logs include job execution details
tail -f log/development.log | grep -i "SessionCleanupJob\|SessionRetentionCleanupJob"
```

## Troubleshooting

### PostgreSQL Connection Issues

If you get database connection errors:

1. Check PostgreSQL is running:
   ```bash
   # macOS
   brew services list | grep postgresql

   # Linux
   sudo systemctl status postgresql
   ```

2. Verify connection settings in `.env` match your PostgreSQL configuration

3. Test connection manually:
   ```bash
   psql -d daybreak_health_backend_development
   ```

### Redis Connection Issues

If Redis is not running:

```bash
# macOS
brew services start redis

# Linux
sudo systemctl start redis
```

### Ruby Version Mismatch

If you see Ruby version errors:

```bash
# Check current Ruby version
ruby -v

# Should be 3.3.x (currently 3.2.0 works but 3.3.x recommended)
# Install correct version using rbenv or RVM (see Prerequisites above)
```

## Next Steps

After completing the setup:

1. Story 1.2 will add database migrations and Active Record models
2. Story 1.3 will implement authentication and encryption
3. Story 1.4 will add Docker configuration for easier development

## Development Workflow

```bash
# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Auto-fix linting issues
bundle exec rubocop -a

# Start Rails console
rails console

# View routes
rails routes
```

## Project Structure

```
daybreak-health-backend/
├── app/
│   ├── controllers/      # API controllers (health check)
│   ├── graphql/          # GraphQL schema, types, mutations
│   ├── jobs/             # Sidekiq background jobs
│   ├── models/           # Active Record models (added in Story 1.2)
│   ├── policies/         # Pundit authorization policies
│   └── services/         # Business logic service objects
├── config/
│   ├── initializers/     # Rails initializers
│   └── routes.rb         # Application routes
├── lib/
│   ├── ai_providers/     # AI provider integrations (Epic 3)
│   └── encryption/       # Data encryption utilities (Story 1.3)
├── spec/                 # RSpec tests
└── .env.example          # Environment variable template
```

## Gems Installed

- **rails** (~> 7.2) - Web framework
- **pg** - PostgreSQL adapter
- **graphql** (~> 2.2) - GraphQL API
- **graphiql-rails** (~> 1.9) - GraphQL IDE (development)
- **sidekiq** (~> 7.2) - Background job processing
- **redis** (~> 5.0) - Redis client
- **jwt** (~> 2.7) - JWT authentication
- **bcrypt** (~> 3.1) - Password hashing
- **pundit** (~> 2.3) - Authorization
- **rack-cors** (~> 2.0) - CORS support
- **rspec-rails** (~> 6.1) - Testing framework
- **factory_bot_rails** (~> 6.4) - Test fixtures
- **rubocop** - Code linting

## Support

For questions or issues, refer to:
- Architecture document: `docs/architecture.md`
- Story details: `docs/sprint-artifacts/1-1-project-scaffolding-and-core-setup.md`
- Tech spec: `docs/sprint-artifacts/tech-spec-epic-1.md`
