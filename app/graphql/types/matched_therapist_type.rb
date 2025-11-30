# frozen_string_literal: true

module Types
  # GraphQL type for a matched therapist with match-specific data
  # Combines therapist profile with match scoring for frontend display
  #
  # Story 5.1: Therapist Matching Results Display
  # This type flattens therapist and match data for easier frontend consumption
  class MatchedTherapistType < Types::BaseObject
    description "A therapist with match-specific data for display"

    field :id, ID, null: false,
          description: "Therapist unique identifier"

    field :name, String, null: false,
          description: "Full name of the therapist"

    field :credentials, String, null: false,
          description: "Professional credentials (e.g., 'LMFT', 'PhD', 'LCSW')"

    field :photo_url, String, null: true,
          description: "Professional photo URL"

    field :specialties, [String], null: false,
          description: "Specialty areas (e.g., 'Anxiety', 'Teen Issues', 'ADHD')"

    field :availability_status, String, null: false,
          description: "Availability status (available, limited, unavailable)"

    field :availability_text, String, null: false,
          description: "Human-readable availability text (e.g., 'Available this week')"

    field :years_of_experience, Integer, null: true,
          description: "Years of professional experience"

    field :bio, String, null: true,
          description: "Brief bio or description"

    field :match_score, Integer, null: false,
          description: "Match quality score (0-100, higher is better)"

    field :match_reasons, [Types::MatchReasonType], null: false,
          description: "Reasons why this therapist was matched"

    field :is_best_match, Boolean, null: false,
          description: "Whether this is the best match (top recommendation)"

    # Resolve therapist ID
    def id
      object[:therapist].id
    end

    # Resolve full name from therapist
    def name
      object[:therapist].full_name
    end

    # Resolve credentials from therapist
    def credentials
      object[:therapist].credentials
    end

    # Resolve photo URL from therapist
    def photo_url
      object[:therapist].photo_url
    end

    # Resolve specialties from therapist specializations
    def specialties
      object[:therapist].specializations
    end

    # Resolve availability status based on score
    def availability_status
      availability = object[:component_scores]&.dig(:availability) || 0
      if availability >= 0.7
        "available"
      elsif availability >= 0.3
        "limited"
      else
        "unavailable"
      end
    end

    # Resolve human-readable availability text
    def availability_text
      next_availability = object[:next_availability]
      return "Check availability" unless next_availability

      days_until = (next_availability - Date.today).to_i
      if days_until <= 3
        "Available this week"
      elsif days_until <= 7
        "Available within a week"
      elsif days_until <= 14
        "Available within 2 weeks"
      else
        "Limited availability"
      end
    end

    # Resolve years of experience (placeholder - can be added to Therapist model)
    def years_of_experience
      # TODO: Add years_of_experience to Therapist model
      # For now, calculate from license_expiration or return nil
      nil
    end

    # Resolve bio from therapist
    def bio
      object[:therapist].bio
    end

    # Resolve match score (0-100)
    def match_score
      object[:score].round
    end

    # Resolve match reasons from reasoning string
    def match_reasons
      reasoning = object[:reasoning] || ""
      # Parse reasoning into structured reasons
      parse_match_reasons(reasoning, object[:component_scores])
    end

    # Whether this is the best match
    def is_best_match
      object[:is_best_match] || false
    end

    private

    # Parse reasoning string into structured match reasons
    #
    # @param reasoning [String] Match reasoning text
    # @param component_scores [Hash] Component scores for generating icons
    # @return [Array<Hash>] Structured match reasons
    def parse_match_reasons(reasoning, component_scores)
      reasons = []

      # Split reasoning by periods and create structured reasons
      reasoning.split(". ").each_with_index do |text, index|
        next if text.blank?

        reason = {
          id: determine_reason_id(text, index),
          text: text.strip.sub(/\.$/, ""), # Remove trailing period
          icon: determine_reason_icon(text)
        }
        reasons << reason
      end

      # Add fallback if no reasons parsed
      if reasons.empty?
        reasons << {
          id: "general_match",
          text: "Good match for your needs",
          icon: "check"
        }
      end

      reasons
    end

    # Determine reason ID based on text content
    #
    # @param text [String] Reason text
    # @param index [Integer] Reason index
    # @return [String] Reason ID
    def determine_reason_id(text, index)
      text_lower = text.downcase
      if text_lower.include?("special")
        "specialty_match"
      elsif text_lower.include?("age") || text_lower.include?("experience")
        "experience_match"
      elsif text_lower.include?("available")
        "availability"
      elsif text_lower.include?("insurance")
        "insurance_match"
      else
        "reason_#{index}"
      end
    end

    # Determine icon based on reason text
    #
    # @param text [String] Reason text
    # @return [String] Icon identifier
    def determine_reason_icon(text)
      text_lower = text.downcase
      if text_lower.include?("special")
        "star"
      elsif text_lower.include?("age") || text_lower.include?("experience")
        "user"
      elsif text_lower.include?("available")
        "calendar"
      elsif text_lower.include?("insurance")
        "shield"
      else
        "check"
      end
    end
  end
end
