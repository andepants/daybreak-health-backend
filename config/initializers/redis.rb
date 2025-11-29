# Redis Configuration
# Used for caching, sessions, and Sidekiq

redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

# Redis will be configured when services need it
# Sidekiq uses its own connection pool (configured in sidekiq.rb)
# Individual services can create Redis instances as needed:
#   Redis.new(url: redis_url)

Rails.logger.info "Redis URL configured: #{redis_url}"
