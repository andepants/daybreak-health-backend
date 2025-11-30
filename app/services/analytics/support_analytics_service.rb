# frozen_string_literal: true

module Analytics
  # Support Analytics Service
  # Story 7.3: Support Request Tracking
  #
  # Provides analytics on support request patterns to identify UX improvements
  #
  # Methods:
  # - requests_by_source: Count requests by widget location
  # - resolution_rate: Percentage of resolved vs. unresolved requests
  # - requests_by_session_status: Group requests by session status
  # - total_requests: Total number of support requests
  # - sessions_with_support: Number of unique sessions that contacted support
  #
  class SupportAnalyticsService
    # Get all support analytics
    #
    # @param start_date [Date, nil] Optional start date filter
    # @param end_date [Date, nil] Optional end date filter
    # @return [Hash] Analytics data
    def self.call(start_date: nil, end_date: nil)
      new(start_date: start_date, end_date: end_date).analytics
    end

    def initialize(start_date: nil, end_date: nil)
      @start_date = start_date
      @end_date = end_date
    end

    # Get all analytics data
    #
    # @return [Hash] Complete analytics breakdown
    def analytics
      {
        total_requests: total_requests,
        sessions_with_support: sessions_with_support,
        resolution_rate: resolution_rate,
        requests_by_source: requests_by_source,
        requests_by_session_status: requests_by_session_status,
        average_resolution_time: average_resolution_time
      }
    end

    # Total number of support requests
    #
    # @return [Integer] Count of support requests
    def total_requests
      support_requests.count
    end

    # Number of unique sessions that contacted support
    #
    # @return [Integer] Count of unique sessions
    def sessions_with_support
      support_requests.distinct.count(:onboarding_session_id)
    end

    # Calculate resolution rate as percentage
    #
    # @return [Float] Percentage of resolved requests (0-100)
    def resolution_rate
      total = total_requests
      return 0.0 if total.zero?

      resolved = support_requests.resolved.count
      (resolved.to_f / total * 100).round(2)
    end

    # Group support requests by source (widget location)
    #
    # @return [Hash] Hash with source as key and count as value
    def requests_by_source
      support_requests
        .group(:source)
        .count
        .transform_keys(&:to_s)
    end

    # Group support requests by onboarding session status
    #
    # @return [Hash] Hash with status as key and count as value
    def requests_by_session_status
      result = support_requests
        .joins(:onboarding_session)
        .group('onboarding_sessions.status')
        .count

      # Transform integer keys to status string keys
      result.each_with_object({}) do |(status_int, count), hash|
        status_name = OnboardingSession.statuses.key(status_int)
        hash[status_name.to_s] = count if status_name
      end
    end

    # Calculate average time to resolution in hours
    #
    # @return [Float, nil] Average hours to resolution, or nil if no resolved requests
    def average_resolution_time
      resolved_requests = support_requests.resolved

      return nil if resolved_requests.empty?

      total_seconds = resolved_requests.sum do |request|
        (request.updated_at - request.created_at).to_i
      end

      average_seconds = total_seconds.to_f / resolved_requests.count
      (average_seconds / 3600).round(2) # Convert to hours
    end

    private

    # Get base support requests scope with date filtering
    #
    # @return [ActiveRecord::Relation] Scoped support requests
    def support_requests
      @support_requests ||= begin
        scope = SupportRequest.all

        if @start_date.present?
          scope = scope.where('support_requests.created_at >= ?', @start_date)
        end

        if @end_date.present?
          scope = scope.where('support_requests.created_at <= ?', @end_date)
        end

        scope
      end
    end
  end
end
