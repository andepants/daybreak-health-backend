# frozen_string_literal: true

# AC 2.6.5: Rate limiting middleware
# Anonymous: 100 req/min, Authenticated: 1000 req/min, System: unlimited

# Require the middleware file before using it
require Rails.root.join('app/middleware/rate_limiter')

Rails.application.config.middleware.use RateLimiter
