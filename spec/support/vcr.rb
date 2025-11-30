# frozen_string_literal: true

require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Don't record actual AWS credentials
  config.filter_sensitive_data("<AWS_ACCESS_KEY_ID>") { ENV["AWS_ACCESS_KEY_ID"] }
  config.filter_sensitive_data("<AWS_SECRET_ACCESS_KEY>") { ENV["AWS_SECRET_ACCESS_KEY"] }
  config.filter_sensitive_data("<S3_BUCKET>") { ENV["S3_BUCKET"] }

  # Allow localhost connections (for Rails server in tests)
  config.ignore_localhost = true

  # Default cassette options
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [:method, :uri, :body]
  }
end

# Allow WebMock to work with VCR
# In test environment, allow all connections since we mock at the service level
WebMock.allow_net_connect!
