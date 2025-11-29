# frozen_string_literal: true

# Rate limiting middleware using Redis
#
# AC 2.6.5: Rate limiting with role-based limits
# - Anonymous users: 100 requests/minute
# - Authenticated users (parent, coordinator, admin): 1000 requests/minute
# - System role: Unlimited (no rate limit)
#
# Uses a sliding window algorithm with Redis for distributed rate limiting.
# Returns 429 (RATE_LIMITED) when threshold is exceeded.
#
# Response headers:
# - X-RateLimit-Limit: Maximum requests allowed
# - X-RateLimit-Remaining: Requests remaining in current window
# - X-RateLimit-Reset: Unix timestamp when limit resets
#
# Example usage in application.rb:
#   config.middleware.use RateLimiter
class RateLimiter
  WINDOW_SIZE = 60 # seconds
  LIMITS = {
    'anonymous' => 100,
    'parent' => 1000,
    'coordinator' => 1000,
    'admin' => 1000,
    'system' => nil # unlimited
  }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    # Extract user info from JWT if present
    user_info = extract_user_info(request)
    role = user_info[:role] || 'anonymous'
    identifier = user_info[:identifier] || request.ip

    # System role has unlimited access
    if role == 'system'
      return @app.call(env)
    end

    # Check rate limit
    limit = LIMITS[role] || LIMITS['anonymous']
    window_key = generate_window_key(role, identifier)

    current_count = increment_counter(window_key)

    # Add rate limit headers to response
    status, headers, body = @app.call(env)
    headers['X-RateLimit-Limit'] = limit.to_s
    headers['X-RateLimit-Remaining'] = [limit - current_count, 0].max.to_s
    headers['X-RateLimit-Reset'] = next_window_reset.to_s

    # Check if limit exceeded
    if current_count > limit
      return rate_limited_response(limit)
    end

    [status, headers, body]
  end

  private

  # Extract user information from JWT token
  #
  # @param request [Rack::Request] The request object
  # @return [Hash] User info with role and identifier
  def extract_user_info(request)
    auth_header = request.env['HTTP_AUTHORIZATION']
    return { role: 'anonymous', identifier: request.ip } if auth_header.blank?

    token = auth_header.gsub(/^Bearer /, '')
    payload = Auth::JwtService.decode(token)

    if payload.present?
      {
        role: payload[:role] || 'anonymous',
        identifier: payload[:session_id] || request.ip
      }
    else
      { role: 'anonymous', identifier: request.ip }
    end
  rescue StandardError => e
    Rails.logger.warn("Rate limiter: Failed to decode JWT: #{e.message}")
    { role: 'anonymous', identifier: request.ip }
  end

  # Generate Redis key for rate limit window
  #
  # @param role [String] User role
  # @param identifier [String] User identifier (session_id or IP)
  # @return [String] Redis key
  def generate_window_key(role, identifier)
    window = current_window
    "rate_limit:#{role}:#{identifier}:#{window}"
  end

  # Get current time window (rounded to WINDOW_SIZE)
  #
  # @return [Integer] Current window timestamp
  def current_window
    (Time.current.to_i / WINDOW_SIZE) * WINDOW_SIZE
  end

  # Get next window reset timestamp
  #
  # @return [Integer] Unix timestamp when current window resets
  def next_window_reset
    current_window + WINDOW_SIZE
  end

  # Increment request counter in Redis
  #
  # @param key [String] Redis key
  # @return [Integer] Current count after increment
  def increment_counter(key)
    redis.multi do |pipeline|
      pipeline.incr(key)
      pipeline.expire(key, WINDOW_SIZE)
    end.first
  rescue Redis::BaseError => e
    Rails.logger.error("Rate limiter: Redis error: #{e.message}")
    # Fail open - allow request if Redis is down
    0
  end

  # Return rate limited error response
  #
  # @param limit [Integer] Rate limit that was exceeded
  # @return [Array] Rack response tuple
  def rate_limited_response(limit)
    retry_after = WINDOW_SIZE - (Time.current.to_i % WINDOW_SIZE)

    error = {
      errors: [
        {
          message: 'Rate limit exceeded. Please try again later.',
          extensions: {
            code: 'RATE_LIMITED',
            timestamp: Time.current.iso8601,
            retryAfter: retry_after
          }
        }
      ]
    }

    headers = {
      'Content-Type' => 'application/json',
      'Retry-After' => retry_after.to_s,
      'X-RateLimit-Limit' => limit.to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => next_window_reset.to_s
    }

    [429, headers, [error.to_json]]
  end

  # Get Redis connection
  #
  # @return [Redis] Redis client
  def redis
    @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
  end
end
