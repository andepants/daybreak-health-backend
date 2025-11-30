source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.2.3"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"
# Use Redis adapter to run Action Cable in production
gem "redis", "~> 5.0"

# Sidekiq for background job processing
gem "sidekiq", "~> 7.2"
gem "sidekiq-cron", "~> 1.9"

# GraphQL
gem "graphql", "~> 2.2"

# GraphQL file uploads (multipart form support)
gem "apollo_upload_server", "~> 2.1"

# JWT for authentication
gem "jwt", "~> 3.1"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Pundit for authorization
gem "pundit", "~> 2.3"

# Phone number validation
gem "phonelib", "~> 0.8"

# AI Providers
gem "ruby-anthropic", "~> 0.4.2"  # Primary AI provider (Anthropic Claude) - renamed from 'anthropic'
gem "ruby-openai", "~> 6.0"  # Backup AI provider (OpenAI)

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# Active Storage S3 backend for HIPAA-compliant image storage
gem "aws-sdk-s3", "~> 1.140"

# AWS Textract for OCR insurance card extraction (Story 4.2)
gem "aws-sdk-textract", "~> 1.50"

# HEIC conversion support
gem "ruby-vips"

# MIME type detection via magic bytes (security)
gem "marcel", "~> 1.0"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem "rack-cors", "~> 2.0"

group :development, :test do
  # Load environment variables from .env
  gem "dotenv-rails", "~> 3.1"

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # RSpec for testing
  gem "rspec-rails", "~> 6.1"

  # Factory Bot for test fixtures
  gem "factory_bot_rails", "~> 6.4"

  # Shoulda Matchers for concise model testing
  gem "shoulda-matchers", "~> 6.0"

  # Pundit Matchers for authorization testing
  gem "pundit-matchers", "~> 3.1"

  # VCR and WebMock for recording/replaying HTTP interactions (Textract API testing)
  gem "vcr", "~> 6.2"
  gem "webmock", "~> 3.19"
end

group :development do
  # GraphiQL for GraphQL development interface
  gem "graphiql-rails", "~> 1.9"
end
