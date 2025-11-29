# syntax=docker/dockerfile:1

# Multi-stage production Dockerfile for Daybreak Health Backend
# Uses Ruby 3.3-alpine for minimal footprint and security

# ============================================
# Builder Stage: Install dependencies and gems
# ============================================
FROM ruby:3.3-alpine AS builder

# Set working directory
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    tzdata \
    nodejs \
    yarn \
    git \
    yaml-dev \
    && rm -rf /var/cache/apk/*

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy application code
COPY . .

# Precompile bootsnap for faster boot times
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# ============================================
# Runtime Stage: Minimal production image
# ============================================
FROM ruby:3.3-alpine AS runtime

# Set working directory
WORKDIR /app

# Install runtime dependencies only
RUN apk add --no-cache \
    postgresql-client \
    tzdata \
    nodejs \
    wget \
    && rm -rf /var/cache/apk/*

# Copy installed gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy application code from builder
COPY --from=builder /app /app

# Create non-root user for security
RUN addgroup -g 1000 -S rails && \
    adduser -u 1000 -S rails -G rails && \
    chown -R rails:rails /app

# Switch to non-root user
USER rails:rails

# Set production environment
ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

# Expose port 3000
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Start Puma web server
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
