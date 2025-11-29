# Aptible Procfile - Process definitions for deployment
# See: https://www.aptible.com/docs/procfile

# Web process: Puma web server for HTTP requests
web: bundle exec puma -C config/puma.rb

# Worker process: Sidekiq background job processor
worker: bundle exec sidekiq -C config/sidekiq.yml

# Release process: Run database migrations before deploying
release: bundle exec rails db:migrate
