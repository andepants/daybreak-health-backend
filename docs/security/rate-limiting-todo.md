# Rate Limiting - TODO

## Context
Story 6-2 Code Review identified the need for rate limiting on cost estimate queries to prevent abuse.

## Issue: H3 - Rate Limiting
**Severity:** HIGH
**Status:** Deferred to future implementation
**Identified:** 2025-11-30

### Problem
The insurance cost estimate query (`insuranceCostEstimate`) lacks rate limiting, which could allow:
- Denial of service attacks through excessive queries
- Abuse of the estimation service
- Potential information gathering attacks

### Recommended Solution
Implement rate limiting using `rack-attack` gem with the following configuration:

```ruby
# config/initializers/rack_attack.rb

class Rack::Attack
  # Throttle cost estimate queries
  # - Allow 10 requests per minute per session
  # - Allow 100 requests per hour per session

  throttle('cost_estimate/session/min', limit: 10, period: 1.minute) do |req|
    if req.path == '/graphql' && req.post?
      # Extract session ID from GraphQL query
      # This requires parsing the request body to identify cost estimate queries
      session_id_from_request(req)
    end
  end

  throttle('cost_estimate/session/hour', limit: 100, period: 1.hour) do |req|
    if req.path == '/graphql' && req.post?
      session_id_from_request(req)
    end
  end

  # Throttle by IP for unauthenticated requests
  throttle('cost_estimate/ip/min', limit: 5, period: 1.minute) do |req|
    if req.path == '/graphql' && req.post?
      req.ip unless session_id_from_request(req)
    end
  end
end
```

### Implementation Checklist
- [ ] Add `rack-attack` gem to Gemfile
- [ ] Create `config/initializers/rack_attack.rb`
- [ ] Configure Redis store for rate limiting (production)
- [ ] Implement GraphQL query detection logic
- [ ] Add custom throttle response messages
- [ ] Set up monitoring/alerting for rate limit violations
- [ ] Add rate limit headers to responses
- [ ] Write tests for rate limiting behavior
- [ ] Document rate limits in API documentation

### Testing Requirements
- Verify rate limits are enforced per session
- Verify rate limits are enforced per IP for unauthenticated requests
- Verify proper HTTP 429 responses
- Verify rate limit reset behavior
- Load test to ensure Redis performance

### References
- rack-attack gem: https://github.com/rack/rack-attack
- GraphQL rate limiting best practices
- Story 6-2 code review notes

### Priority
Implement before production launch or when exposing API to external clients.
