# frozen_string_literal: true

module Sessions
  # Service to merge new progress data with existing session progress
  # Uses deep merge strategy with special handling for arrays
  class ProgressMerger
    attr_reader :session, :new_progress

    def initialize(session, new_progress)
      @session = session
      @new_progress = new_progress.deep_stringify_keys
    end

    def call
      existing_progress = session.progress || {}
      merge_progress(existing_progress, new_progress)
    end

    private

    def merge_progress(existing, new_data)
      # Deep merge with custom array handling
      existing.deep_merge(new_data) do |key, old_val, new_val|
        if key == 'completedSteps' && old_val.is_a?(Array) && new_val.is_a?(Array)
          # For completedSteps, merge arrays and remove duplicates
          (old_val + new_val).uniq
        elsif old_val.is_a?(Hash) && new_val.is_a?(Hash)
          # Recursively merge nested hashes
          merge_progress(old_val, new_val)
        else
          # For all other values, new value wins
          new_val
        end
      end
    end
  end
end
