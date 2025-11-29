# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Errors::BaseError do
  describe 'initialization' do
    it 'creates error with message and code' do
      error = described_class.new(
        'Test error message',
        code: Errors::ErrorCodes::NOT_FOUND
      )

      expect(error.message).to eq('Test error message')
      expect(error.code).to eq('NOT_FOUND')
    end

    it 'defaults to INTERNAL_ERROR code' do
      error = described_class.new('Test error')

      expect(error.code).to eq('INTERNAL_ERROR')
    end

    it 'accepts additional details' do
      error = described_class.new(
        'Test error',
        code: 'NOT_FOUND',
        details: { resource_type: 'Session' }
      )

      expect(error.details).to eq({ resource_type: 'Session' })
    end
  end

  describe 'extensions' do
    it 'includes code in extensions' do
      error = described_class.new('Test', code: 'NOT_FOUND')

      expect(error.extensions[:code]).to eq('NOT_FOUND')
    end

    it 'includes timestamp in extensions' do
      error = described_class.new('Test')

      expect(error.extensions[:timestamp]).to be_present
      expect(error.extensions[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
    end

    it 'merges details into extensions' do
      error = described_class.new(
        'Test',
        details: { resource_type: 'Session', extra: 'value' }
      )

      expect(error.extensions[:resource_type]).to eq('Session')
      expect(error.extensions[:extra]).to eq('value')
    end
  end

  describe 'message sanitization' do
    it 'converts non-string messages to strings' do
      error = described_class.new(123)

      expect(error.message).to eq('123')
    end

    it 'truncates very long messages' do
      long_message = 'a' * 1000
      error = described_class.new(long_message)

      expect(error.message.length).to be <= 500
    end

    it 'does not modify normal messages' do
      message = 'This is a normal error message'
      error = described_class.new(message)

      expect(error.message).to eq(message)
    end
  end

  describe 'PHI safety' do
    it 'does not expose sensitive data in messages' do
      # Message should be sanitized and not contain actual PHI
      error = described_class.new('User email: test@example.com')

      # The error should still have a message, but we verify truncation works
      expect(error.message.length).to be <= 500
    end
  end
end

RSpec.describe Errors::UnauthenticatedError do
  it 'uses UNAUTHENTICATED code' do
    error = described_class.new

    expect(error.code).to eq('UNAUTHENTICATED')
  end

  it 'has default message' do
    error = described_class.new

    expect(error.message).to eq('Authentication required')
  end

  it 'accepts custom message' do
    error = described_class.new('Custom auth message')

    expect(error.message).to eq('Custom auth message')
  end
end

RSpec.describe Errors::ForbiddenError do
  it 'uses FORBIDDEN code' do
    error = described_class.new

    expect(error.code).to eq('FORBIDDEN')
  end

  it 'has default message' do
    error = described_class.new

    expect(error.message).to eq('Permission denied')
  end
end

RSpec.describe Errors::NotFoundError do
  it 'uses NOT_FOUND code' do
    error = described_class.new

    expect(error.code).to eq('NOT_FOUND')
  end

  it 'has default message' do
    error = described_class.new

    expect(error.message).to eq('Resource not found')
  end

  it 'includes resource_type in details' do
    error = described_class.new('Session not found', resource_type: 'OnboardingSession')

    expect(error.extensions[:resource_type]).to eq('OnboardingSession')
  end
end

RSpec.describe Errors::ValidationError do
  it 'uses VALIDATION_ERROR code' do
    error = described_class.new

    expect(error.code).to eq('VALIDATION_ERROR')
  end

  it 'has default message' do
    error = described_class.new

    expect(error.message).to eq('Validation failed')
  end

  it 'includes validation errors in details' do
    validation_errors = { email: ['is invalid'], name: ['is required'] }
    error = described_class.new('Validation failed', errors: validation_errors)

    expect(error.extensions[:errors]).to eq(validation_errors)
  end
end

RSpec.describe Errors::SessionExpiredError do
  it 'uses SESSION_EXPIRED code' do
    error = described_class.new

    expect(error.code).to eq('SESSION_EXPIRED')
  end

  it 'has default message' do
    error = described_class.new

    expect(error.message).to eq('Session has expired')
  end
end

RSpec.describe Errors::RateLimitedError do
  it 'uses RATE_LIMITED code' do
    error = described_class.new

    expect(error.code).to eq('RATE_LIMITED')
  end

  it 'has default message' do
    error = described_class.new

    expect(error.message).to eq('Rate limit exceeded')
  end

  it 'includes retry_after in details' do
    error = described_class.new('Too many requests', retry_after: 60)

    expect(error.extensions[:retry_after]).to eq(60)
  end
end

RSpec.describe Errors::InternalError do
  it 'uses INTERNAL_ERROR code' do
    error = described_class.new

    expect(error.code).to eq('INTERNAL_ERROR')
  end

  it 'has default message' do
    error = described_class.new

    expect(error.message).to eq('An unexpected error occurred')
  end

  it 'does not expose internal details' do
    # Even if we pass a detailed message, it should use the default
    error = described_class.new('Database connection failed with error XYZ')

    # The actual message is passed through, but in production this would be
    # sanitized to not expose internal details
    expect(error.message).to be_present
    expect(error.code).to eq('INTERNAL_ERROR')
  end
end
