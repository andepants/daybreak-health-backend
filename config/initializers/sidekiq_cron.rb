# frozen_string_literal: true

# Sidekiq-cron scheduled jobs configuration
#
# This initializer sets up recurring background jobs using Sidekiq-cron.
# Jobs are defined with cron expressions and are automatically scheduled
# when the Rails application starts.
#
# AC 2.4.5: Cleanup job runs every 15 minutes via scheduled task
#
# Cron expression format: minute hour day month day_of_week
# Example: '*/15 * * * *' = every 15 minutes
#
# View scheduled jobs in Sidekiq web UI at: /sidekiq/cron

if defined?(Sidekiq::Cron)
  schedule = {
    'session_cleanup' => {
      'cron' => '*/15 * * * *', # Every 15 minutes
      'class' => 'SessionCleanupJob',
      'queue' => 'default',
      'description' => 'Expire inactive sessions past their expiration time'
    },
    'session_retention_cleanup' => {
      'cron' => '0 2 * * 0', # Weekly on Sunday at 2 AM
      'class' => 'SessionRetentionCleanupJob',
      'queue' => 'low',
      'description' => 'Delete expired sessions after retention period (90 days)'
    }
  }

  Sidekiq::Cron::Job.load_from_hash(schedule)

  Rails.logger.info('Sidekiq-cron: Loaded scheduled jobs')
end
