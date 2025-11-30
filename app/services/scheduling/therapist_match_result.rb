# frozen_string_literal: true

module Scheduling
  # Value object representing a single therapist match result
  # Contains therapist, score, component scores, reasoning, and availability
  #
  # Story 5.3: AI Matching Algorithm
  class TherapistMatchResult
    attr_reader :therapist, :score, :component_scores, :reasoning, :next_availability

    # Initialize a therapist match result
    #
    # @param therapist [Therapist] Matched therapist
    # @param score [Float] Overall match score (0-100)
    # @param component_scores [Hash] Individual scoring components
    # @param reasoning [String] Parent-friendly explanation of match
    # @param next_availability [Date, nil] Next available appointment date
    def initialize(therapist:, score:, component_scores:, reasoning:, next_availability: nil)
      @therapist = therapist
      @score = score.round(2)
      @component_scores = component_scores
      @reasoning = reasoning
      @next_availability = next_availability
    end

    # Convert to hash for JSON serialization
    #
    # @return [Hash] Serialized match result
    def to_h
      {
        therapist_id: therapist.id,
        therapist_name: therapist.full_name,
        score: score,
        component_scores: component_scores,
        reasoning: reasoning,
        next_availability: next_availability&.iso8601,
        therapist_details: {
          bio: therapist.bio,
          credentials: therapist.credentials,
          specializations: therapist.specializations,
          languages: therapist.languages,
          photo_url: therapist.photo_url
        }
      }
    end

    # Get specialization match score
    #
    # @return [Float] Specialization component score (0.0-1.0)
    def specialization_score
      component_scores[:specialization] || 0.0
    end

    # Get age range fit score
    #
    # @return [Float] Age range component score (0.0-1.0)
    def age_range_score
      component_scores[:age_range] || 0.0
    end

    # Get availability score
    #
    # @return [Float] Availability component score (0.0-1.0)
    def availability_score
      component_scores[:availability] || 0.0
    end

    # Get treatment modality score
    #
    # @return [Float] Treatment modality component score (0.0-1.0)
    def modality_score
      component_scores[:treatment_modality] || 0.0
    end

    # Compare matches by score for sorting
    #
    # @param other [TherapistMatchResult] Other match to compare
    # @return [Integer] -1, 0, or 1
    def <=>(other)
      # Sort descending by score (highest first)
      other.score <=> score
    end

    # Check if match is considered strong (score >= 70)
    #
    # @return [Boolean] True if strong match
    def strong_match?
      score >= 70.0
    end

    # Check if match is considered good (score >= 50)
    #
    # @return [Boolean] True if good match
    def good_match?
      score >= 50.0
    end

    # Check if therapist is available within 2 weeks
    #
    # @return [Boolean] True if available soon
    def available_soon?
      return false unless next_availability

      next_availability <= 14.days.from_now.to_date
    end
  end
end
