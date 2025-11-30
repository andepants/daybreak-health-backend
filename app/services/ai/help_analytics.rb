# frozen_string_literal: true

module Ai
  # Help Analytics Service (Story 3.3)
  # Analyzes help requests and off-topic messages to identify UX improvement opportunities
  #
  # Acceptance Criteria:
  # - AC: Track which questions cause confusion for UX improvement
  # - AC: Store intent classification results in message metadata
  # - AC: Provide analytics on help request patterns
  #
  # Usage:
  #   analytics = Ai::HelpAnalytics.new
  #   report = analytics.generate_report(days: 7)
  class HelpAnalytics
    # Generate help request analytics report
    # Shows which fields and questions are causing the most confusion
    #
    # @param days [Integer] Number of days to analyze (default: 30)
    # @return [Hash] Analytics report
    def generate_report(days: 30)
      start_date = days.days.ago
      messages = Message.where('created_at >= ?', start_date).where(role: :user)

      {
        period: {
          start: start_date,
          end: Time.current,
          days: days
        },
        total_messages: messages.count,
        help_requests: help_request_stats(messages),
        off_topic: off_topic_stats(messages),
        questions: question_stats(messages),
        confusion_patterns: confusion_patterns(messages),
        recommendations: generate_recommendations(messages)
      }
    end

    # Get help request statistics
    #
    # @param messages [ActiveRecord::Relation] Messages to analyze
    # @return [Hash] Help request statistics
    def help_request_stats(messages)
      help_messages = messages.select { |m| m.help_request? }

      {
        count: help_messages.count,
        percentage: percentage(help_messages.count, messages.count),
        by_pattern: group_by_pattern(help_messages),
        by_confidence: group_by_confidence(help_messages)
      }
    end

    # Get off-topic statistics
    #
    # @param messages [ActiveRecord::Relation] Messages to analyze
    # @return [Hash] Off-topic statistics
    def off_topic_stats(messages)
      off_topic_messages = messages.select { |m| m.off_topic? }

      {
        count: off_topic_messages.count,
        percentage: percentage(off_topic_messages.count, messages.count),
        by_pattern: group_by_pattern(off_topic_messages)
      }
    end

    # Get question statistics
    #
    # @param messages [ActiveRecord::Relation] Messages to analyze
    # @return [Hash] Question statistics
    def question_stats(messages)
      question_messages = messages.select { |m| m.question? }

      {
        count: question_messages.count,
        percentage: percentage(question_messages.count, messages.count)
      }
    end

    # Identify patterns that cause confusion
    # These are help requests or repeated questions about the same field
    #
    # @param messages [ActiveRecord::Relation] Messages to analyze
    # @return [Array<Hash>] Confusion patterns sorted by frequency
    def confusion_patterns(messages)
      help_messages = messages.select { |m| m.help_request? || m.question? }

      patterns = help_messages.group_by { |m| m.metadata&.dig('intent_pattern') }
                              .map { |pattern, msgs| { pattern: pattern, count: msgs.count } }
                              .sort_by { |p| -p[:count] }
                              .take(10)

      patterns
    end

    # Generate UX recommendations based on analytics
    #
    # @param messages [ActiveRecord::Relation] Messages to analyze
    # @return [Array<String>] Recommendations for UX improvements
    def generate_recommendations(messages)
      recommendations = []
      help_percentage = percentage(messages.count { |m| m.help_request? }, messages.count)

      # High help request rate
      if help_percentage > 20
        recommendations << "High help request rate (#{help_percentage}%) - Consider improving " \
                          "field labels and inline help text"
      end

      # Check for specific confusion patterns
      confusion = confusion_patterns(messages)
      if confusion.any?
        top_pattern = confusion.first
        if top_pattern[:count] > 5
          recommendations << "Pattern '#{top_pattern[:pattern]}' appears #{top_pattern[:count]} times - " \
                            "Consider adding proactive explanation"
        end
      end

      # Off-topic rate
      off_topic_percentage = percentage(messages.count { |m| m.off_topic? }, messages.count)
      if off_topic_percentage > 15
        recommendations << "High off-topic rate (#{off_topic_percentage}%) - Consider adding FAQ " \
                          "section or better expectation setting"
      end

      recommendations << "No major issues detected" if recommendations.empty?

      recommendations
    end

    # Get sessions with high help request rates
    # Identifies sessions where parent is struggling
    #
    # @param threshold [Integer] Minimum number of help requests (default: 3)
    # @return [Array<Hash>] Sessions with help request counts
    def sessions_needing_support(threshold: 3)
      sessions = OnboardingSession.includes(:messages).all

      struggling_sessions = sessions.map do |session|
        help_count = session.messages.count { |m| m.help_request? }
        next if help_count < threshold

        {
          session_id: session.id,
          help_request_count: help_count,
          total_messages: session.messages.count,
          help_percentage: percentage(help_count, session.messages.count)
        }
      end.compact

      struggling_sessions.sort_by { |s| -s[:help_request_count] }
    end

    # Log help interaction for audit trail
    # AC: Audit logging for help interactions
    #
    # @param message [Message] Message that triggered help
    # @param intent_result [Hash] Intent classification result
    def log_help_interaction(message, intent_result)
      AuditLog.create!(
        onboarding_session_id: message.onboarding_session_id,
        action: 'HELP_REQUEST',
        resource: 'Message',
        resource_id: message.id,
        details: {
          intent: intent_result[:intent],
          confidence: intent_result[:confidence],
          pattern: intent_result[:pattern],
          timestamp: Time.current.iso8601
          # NOTE: Never log actual message content (PHI)
        }
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("Failed to log help interaction: #{e.message}")
      # Don't fail the request if logging fails
    end

    private

    # Calculate percentage with safety
    #
    # @param part [Integer] Part count
    # @param total [Integer] Total count
    # @return [Float] Percentage (0.0-100.0)
    def percentage(part, total)
      return 0.0 if total.zero?

      ((part.to_f / total) * 100).round(2)
    end

    # Group messages by intent pattern
    #
    # @param messages [Array<Message>] Messages to group
    # @return [Hash] Pattern counts
    def group_by_pattern(messages)
      messages.group_by { |m| m.metadata&.dig('intent_pattern') }
              .transform_values(&:count)
              .sort_by { |_pattern, count| -count }
              .to_h
    end

    # Group messages by confidence level
    #
    # @param messages [Array<Message>] Messages to group
    # @return [Hash] Confidence level counts
    def group_by_confidence(messages)
      {
        high: messages.count { |m| (m.intent_confidence || 0) >= 0.8 },
        medium: messages.count { |m| (m.intent_confidence || 0).between?(0.5, 0.8) },
        low: messages.count { |m| (m.intent_confidence || 0) < 0.5 }
      }
    end
  end
end
