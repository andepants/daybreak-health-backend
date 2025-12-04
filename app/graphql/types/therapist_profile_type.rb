# frozen_string_literal: true

module Types
  # GraphQL type for detailed therapist profile view
  #
  # Combines full therapist profile with session-specific match data.
  # Used by the TherapistProfileSheet component to display extended profile information.
  #
  # Story 5.1: Therapist Matching Results Display (Frontend)
  # Provides profile data for the "View Profile" action on therapist cards.
  class TherapistProfileType < Types::BaseObject
    description "Detailed therapist profile with match-specific data"

    # Core profile fields
    field :id, ID, null: false,
          description: "Therapist unique identifier"

    field :name, String, null: false,
          description: "Full name of the therapist"

    field :credentials, String, null: false,
          description: "Professional credentials (e.g., 'LMFT', 'PhD', 'LCSW')"

    field :photo_url, String, null: true,
          description: "Professional photo URL"

    field :bio, String, null: true,
          description: "Detailed biography"

    field :specialties, [String], null: false,
          description: "Specialty areas (e.g., 'Anxiety', 'Teen Issues', 'ADHD')"

    field :years_of_experience, Integer, null: true,
          description: "Years of professional experience"

    # Extended profile fields
    field :approach, String, null: true,
          description: "Therapeutic approach description"

    field :languages, [String], null: false,
          description: "Languages spoken"

    field :education, [Types::EducationType], null: false,
          description: "Education and degrees"

    field :certifications, [String], null: false,
          description: "Professional certifications"

    # Match-specific fields (when session_id is provided)
    field :match_reasons, [Types::MatchReasonType], null: false,
          description: "Reasons why this therapist was matched (requires session_id)" do
      argument :session_id, ID, required: true, description: "Session ID for match-specific reasons"
    end

    # Availability fields
    field :availability_status, String, null: false,
          description: "Availability status (available, limited, unavailable)"

    field :availability_text, String, null: false,
          description: "Human-readable availability text"

    field :available_slots, [Types::TimeSlotType], null: false,
          description: "Next available appointment slots" do
      argument :limit, Integer, required: false, default_value: 3, description: "Maximum slots to return"
    end

    # Resolve therapist ID
    def id
      therapist.id
    end

    # Resolve full name from therapist
    def name
      therapist.full_name
    end

    # Resolve credentials from therapist
    def credentials
      therapist.license_type || "Licensed Therapist"
    end

    # Resolve photo URL from therapist
    def photo_url
      therapist.photo_url
    end

    # Resolve bio from therapist
    def bio
      therapist.bio
    end

    # Resolve specialties from therapist specializations
    def specialties
      therapist.specializations
    end

    # Resolve years of experience from model
    def years_of_experience
      therapist.years_of_experience
    end

    # Resolve therapeutic approach from model profile_data
    def approach
      therapist.approach
    end

    # Resolve languages from model
    def languages
      therapist.languages.presence || ["English"]
    end

    # Resolve education from model profile_data
    # Returns array of education entries with degree, institution, year
    def education
      therapist.education.map do |edu|
        {
          degree: edu["degree"] || edu[:degree] || "Degree",
          institution: edu["institution"] || edu[:institution] || "Institution",
          year: edu["year"] || edu[:year]
        }
      end
    end

    # Resolve certifications from model profile_data
    # Falls back to treatment_modalities if no certifications
    def certifications
      therapist.certifications
    end

    # Resolve match reasons for a specific session
    def match_reasons(session_id:)
      return [] unless object[:match_data]

      reasoning = object[:match_data][:reasoning] || ""
      component_scores = object[:match_data][:component_scores] || {}

      parse_match_reasons(reasoning, component_scores)
    end

    # Resolve availability status
    def availability_status
      if object[:match_data] && object[:match_data][:component_scores]
        availability = object[:match_data][:component_scores][:availability] || 0
        if availability >= 0.7
          "available"
        elsif availability >= 0.3
          "limited"
        else
          "unavailable"
        end
      else
        check_availability_status
      end
    end

    # Resolve human-readable availability text
    def availability_text
      if object[:match_data] && object[:match_data][:next_availability]
        next_availability = object[:match_data][:next_availability]
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
      else
        "Check availability"
      end
    end

    # Resolve available slots
    def available_slots(limit:)
      start_date = Date.today
      end_date = 14.days.from_now.to_date

      slots = Scheduling::AvailabilityService.available_slots(
        therapist_id: therapist.id,
        start_date: start_date,
        end_date: end_date
      )

      slots.first(limit).map { |slot| OpenStruct.new(slot) }
    rescue StandardError => e
      Rails.logger.error("Failed to load available slots: #{e.message}")
      []
    end

    private

    # Get therapist from object
    def therapist
      object[:therapist] || object
    end

    # Check availability status when no match data
    def check_availability_status
      start_date = Date.today
      end_date = 7.days.from_now.to_date

      slots = Scheduling::AvailabilityService.available_slots(
        therapist_id: therapist.id,
        start_date: start_date,
        end_date: end_date
      )

      if slots.length >= 5
        "available"
      elsif slots.length > 0
        "limited"
      else
        "unavailable"
      end
    rescue StandardError
      "unavailable"
    end

    # Parse reasoning string into structured match reasons
    def parse_match_reasons(reasoning, component_scores)
      reasons = []

      reasoning.split(". ").each_with_index do |text, index|
        next if text.blank?

        reason = {
          id: determine_reason_id(text, index),
          text: text.strip.sub(/\.$/, ""),
          icon: determine_reason_icon(text)
        }
        reasons << reason
      end

      if reasons.empty?
        reasons << {
          id: "general_match",
          text: "Good match for your needs",
          icon: "check"
        }
      end

      reasons
    end

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
