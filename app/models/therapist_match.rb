# frozen_string_literal: true

# TherapistMatch model
# Stores matching results for analytics and tracking parent selections
#
# Story 5.3: AI Matching Algorithm
class TherapistMatch < ApplicationRecord
  # Associations
  belongs_to :onboarding_session

  # Validations
  validates :matched_therapists, presence: true
  validates :criteria_used, presence: true
  validates :processing_time_ms, presence: true, numericality: { greater_than: 0 }

  # Get matched therapists data
  #
  # @return [Array<Hash>] Array of matched therapist data with scores
  def therapist_matches
    matched_therapists.is_a?(Array) ? matched_therapists : []
  end

  # Get matching criteria
  #
  # @return [Hash] Criteria used for matching
  def criteria
    criteria_used.is_a?(Hash) ? criteria_used.with_indifferent_access : {}
  end

  # Get selected therapist
  #
  # @return [Therapist, nil] Selected therapist or nil
  def selected_therapist
    return nil unless selected_therapist_id

    Therapist.find_by(id: selected_therapist_id)
  end

  # Mark therapist as selected by parent
  #
  # @param therapist_id [String] UUID of selected therapist
  # @return [Boolean] True if update successful
  def mark_selected(therapist_id)
    update(selected_therapist_id: therapist_id)
  end

  # Get top N matches
  #
  # @param limit [Integer] Number of matches to return (default: 3)
  # @return [Array<Hash>] Top N matched therapists
  def top_matches(limit = 3)
    therapist_matches.first(limit)
  end

  # Get average match score
  #
  # @return [Float] Average score across all matches
  def average_score
    return 0.0 if therapist_matches.empty?

    scores = therapist_matches.map { |m| m['score'] || 0 }
    scores.sum.to_f / scores.length
  end

  # Check if parent selected highest-scored match
  #
  # @return [Boolean, nil] True if selected top match, nil if no selection
  def selected_top_match?
    return nil unless selected_therapist_id
    return nil if therapist_matches.empty?

    top_match = therapist_matches.first
    top_match['therapist_id'] == selected_therapist_id
  end
end
