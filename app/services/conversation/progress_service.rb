# frozen_string_literal: true

module Conversation
  # Service to calculate session progress indicators
  #
  # Calculates:
  # - Progress percentage based on completed required fields
  # - Current and completed phases
  # - Next phase preview
  # - Estimated time remaining with adaptive learning
  #
  # Progress is monotonic (never decreases) per AC7.
  class ProgressService
    attr_reader :session

    def initialize(session)
      @session = session
    end

    # Calculate all progress indicators
    # Uses Redis caching with 1-hour TTL for performance
    #
    # @return [Hash] Progress data with keys:
    #   - percentage: Integer (0-100)
    #   - current_phase: String
    #   - completed_phases: Array<String>
    #   - next_phase: String|nil
    #   - estimated_minutes_remaining: Integer
    def calculate
      # AC7: Try to fetch from cache first
      cached = fetch_from_cache
      return cached if cached.present?

      # Calculate progress indicators
      progress = {
        percentage: calculate_percentage,
        current_phase: current_phase,
        completed_phases: completed_phases,
        next_phase: next_phase,
        estimated_minutes_remaining: estimate_remaining_time
      }

      # Cache the result
      write_to_cache(progress)

      progress
    end

    # Invalidate the progress cache for this session
    # Should be called when session progress is updated
    def self.invalidate_cache(session)
      cache_key = "daybreak:progress:#{session.id}"
      Rails.cache.delete(cache_key)
    end

    private

    # Calculate progress percentage from completed required fields
    # AC1: Progress percentage calculated from completed vs. required fields
    # AC7: Progress never goes backward (monotonic)
    #
    # @return [Integer] Progress percentage (0-100)
    def calculate_percentage
      completed = count_completed_fields
      required = ONBOARDING_TOTAL_REQUIRED_FIELDS

      return 0 if required.zero?

      # Calculate raw percentage
      raw_percentage = (completed * 100.0 / required).floor

      # AC7: Ensure monotonic progress (never decrease)
      last_percentage = session.progress&.dig('last_percentage') || 0
      [raw_percentage, last_percentage].max
    end

    # Count completed required fields across all phases
    #
    # @return [Integer] Number of completed required fields
    def count_completed_fields
      intake_data = session.progress&.dig('intake') || {}
      insurance_data = session.progress&.dig('insurance') || {}

      completed_count = 0

      # Parent info fields (6 required)
      if intake_data['parentInfoComplete']
        completed_count += ONBOARDING_PHASES[:parent_info][:required_fields]
      else
        # Count individual parent fields
        parent_fields = %w[firstName lastName email phone relationship isGuardian]
        parent_fields.each do |field|
          completed_count += 1 if intake_data.dig('parent', field).present?
        end
      end

      # Child info fields (4 required)
      if intake_data['childInfoComplete']
        completed_count += ONBOARDING_PHASES[:child_info][:required_fields]
      else
        # Count individual child fields
        child_fields = %w[firstName lastName dateOfBirth concerns]
        child_fields.each do |field|
          completed_count += 1 if intake_data.dig('child', field).present?
        end
      end

      # Concerns (1 required)
      completed_count += 1 if intake_data.dig('concerns', 'primaryConcerns').present?

      # Insurance (3 required: payerName, memberId, groupNumber OR selfPay flag)
      if insurance_data['selfPay']
        completed_count += ONBOARDING_PHASES[:insurance][:required_fields]
      elsif insurance_data['verificationStatus'] == 'verified'
        completed_count += ONBOARDING_PHASES[:insurance][:required_fields]
      else
        # Count individual insurance fields
        insurance_fields = %w[payerName memberId groupNumber]
        insurance_fields.each do |field|
          completed_count += 1 if insurance_data[field].present?
        end
      end

      # Assessment has variable required fields, so we don't count them
      # Completion is indicated by assessment.screeningComplete flag

      completed_count
    end

    # Get current phase from session progress
    # AC2: Current phase is displayed
    #
    # @return [String] Current phase name
    def current_phase
      step = session.progress&.dig('currentStep')
      return 'welcome' if step.blank?

      # Normalize step name to phase name
      normalize_phase_name(step)
    end

    # Get array of completed phases
    # AC4: Completed phases shown as checkmarks
    #
    # @return [Array<String>] Completed phase names
    def completed_phases
      steps = session.progress&.dig('completedSteps') || []
      steps.map { |step| normalize_phase_name(step) }.uniq
    end

    # Get next phase in sequence
    # AC5: Next phase preview available
    #
    # @return [String|nil] Next phase name or nil if at end
    def next_phase
      current_idx = ONBOARDING_PHASE_ORDER.index(current_phase.to_sym)
      return nil if current_idx.nil? || current_idx >= ONBOARDING_PHASE_ORDER.length - 1

      ONBOARDING_PHASE_ORDER[current_idx + 1].to_s
    end

    # Estimate remaining time in minutes
    # AC3: Estimated time based on average completion times
    # AC8: Time estimate adjusts based on actual progress rate
    #
    # @return [Integer] Estimated minutes remaining
    def estimate_remaining_time
      current_idx = ONBOARDING_PHASE_ORDER.index(current_phase.to_sym)
      return 0 if current_idx.nil?

      # Get remaining phases
      remaining_phases = ONBOARDING_PHASE_ORDER[(current_idx + 1)..-1] || []

      # Calculate baseline estimate
      baseline_estimate = remaining_phases.sum do |phase|
        ONBOARDING_PHASES[phase][:baseline_minutes]
      end

      # AC8: Apply adaptive adjustment based on user's actual pace
      pace_multiplier = calculate_pace_multiplier
      (baseline_estimate * pace_multiplier).ceil
    end

    # Calculate pace multiplier based on actual vs. baseline times
    # AC8: Adaptive time estimation
    #
    # @return [Float] Pace multiplier (1.0 = normal, >1.0 = slower, <1.0 = faster)
    def calculate_pace_multiplier
      phase_timings = session.progress&.dig('phaseTimings') || {}
      return 1.0 if phase_timings.empty?

      # Calculate actual vs. baseline ratio for completed phases
      total_actual = 0
      total_baseline = 0

      phase_timings.each do |phase, timing|
        next unless timing['completed_at'].present? && timing['started_at'].present?

        phase_sym = normalize_phase_name(phase).to_sym
        next unless ONBOARDING_PHASES.key?(phase_sym)

        actual_duration = (Time.parse(timing['completed_at']) - Time.parse(timing['started_at'])) / 60.0
        baseline_duration = ONBOARDING_PHASES[phase_sym][:baseline_minutes]

        total_actual += actual_duration
        total_baseline += baseline_duration
      end

      return 1.0 if total_baseline.zero?

      # Calculate pace multiplier with bounds (0.5x to 2.0x)
      multiplier = total_actual / total_baseline
      [[multiplier, 0.5].max, 2.0].min
    end

    # Normalize phase/step name to standard format
    #
    # @param name [String] Phase or step name
    # @return [String] Normalized phase name
    def normalize_phase_name(name)
      return 'welcome' if name.blank?

      # Convert camelCase or snake_case to snake_case
      normalized = name.to_s.underscore

      # Map common variations
      case normalized
      when 'welcome', 'intro', 'start'
        'welcome'
      when 'parent_info', 'parent', 'guardian_info'
        'parent_info'
      when 'child_info', 'child'
        'child_info'
      when 'concerns', 'primary_concerns'
        'concerns'
      when 'insurance', 'insurance_info'
        'insurance'
      when 'assessment', 'screening', 'questionnaire'
        'assessment'
      else
        # Default to the normalized name
        normalized
      end
    end

    # Fetch progress from Redis cache
    #
    # @return [Hash|nil] Cached progress data or nil if cache miss
    def fetch_from_cache
      cache_key = "daybreak:progress:#{session.id}"
      cached = Rails.cache.read(cache_key)

      # Return nil if cache miss or if cached data is invalid
      return nil if cached.blank?
      return nil unless cached.is_a?(Hash)

      cached.with_indifferent_access
    rescue StandardError => e
      Rails.logger.warn("Failed to read progress cache: #{e.message}")
      nil
    end

    # Write progress to Redis cache with 1-hour TTL
    #
    # @param progress [Hash] Progress data to cache
    def write_to_cache(progress)
      cache_key = "daybreak:progress:#{session.id}"
      Rails.cache.write(cache_key, progress, expires_in: 1.hour)
    rescue StandardError => e
      Rails.logger.warn("Failed to write progress cache: #{e.message}")
      # Don't raise - caching is optional optimization
    end
  end
end
