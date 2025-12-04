# frozen_string_literal: true

module Scheduling
  # AI-powered therapist matching service
  # Analyzes child assessment data and recommends matching therapists
  #
  # Story 5.3: AI Matching Algorithm
  #
  # Usage:
  #   service = Scheduling::MatchingService.new(session_id: session.id)
  #   matches = service.match
  #
  # Scoring Weights:
  #   - Specialization match: 40%
  #   - Age range fit: 30%
  #   - Availability: 20%
  #   - Treatment modality: 10%
  class MatchingService
    # Scoring weights
    WEIGHTS = {
      specialization: 0.40,
      age_range: 0.30,
      availability: 0.20,
      treatment_modality: 0.10
    }.freeze

    # Minimum number of recommendations to return
    MIN_RECOMMENDATIONS = 3

    # Maximum processing time (3 seconds for AC6)
    MAX_PROCESSING_TIME_MS = 3000

    # AI timeout for semantic matching (2 seconds)
    AI_TIMEOUT_SECONDS = 2

    attr_reader :session_id, :session, :child, :insurance, :assessment, :patient_availabilities

    # Initialize matching service
    #
    # @param session_id [String] UUID of onboarding session
    def initialize(session_id:)
      @session_id = session_id
      @start_time = Time.current
      @cache_hits = 0
      @cache_misses = 0
    end

    # Execute matching algorithm
    # AC1, AC2, AC3, AC4, AC5, AC6: Main matching method
    #
    # @return [Array<TherapistMatchResult>] Ranked list of therapist matches
    # @raise [ArgumentError] If session not found or incomplete
    def match
      load_session_data!
      validate_session_data!

      # Check cache first (AC6: Performance optimization)
      cached_result = fetch_cached_result
      return cached_result if cached_result

      # Extract matching criteria (AC1)
      criteria = extract_matching_criteria

      # Get candidate therapists with hard filters
      candidates = fetch_candidate_therapists(criteria)

      # Score and rank candidates (AC2, AC3)
      matches = score_therapists(candidates, criteria)

      # Sort by score descending
      matches.sort!

      # Take top N recommendations (AC5)
      top_matches = matches.first([MIN_RECOMMENDATIONS, matches.length].max)

      # Store results for analytics
      store_match_results(top_matches, criteria)

      # Cache results (10 minute TTL)
      cache_match_results(top_matches)

      top_matches
    end

    private

    # Load session and associated data
    def load_session_data!
      @session = OnboardingSession.includes(
        :child,
        :insurance,
        :assessment,
        :patient_availabilities
      ).find_by(id: session_id)

      raise ArgumentError, "Session not found: #{session_id}" unless @session

      @child = @session.child
      @insurance = @session.insurance
      @assessment = @session.assessment
      @patient_availabilities = @session.patient_availabilities.to_a
    end

    # Validate session has required data for matching
    def validate_session_data!
      raise ArgumentError, "Session must have child data" unless @child
      raise ArgumentError, "Session must have insurance data" unless @insurance
      raise ArgumentError, "Session must have assessment data" unless @assessment
      raise ArgumentError, "Assessment must be complete" unless @assessment.status == "complete"
    end

    # Extract matching criteria from session data (AC1)
    #
    # @return [Hash] Matching criteria
    def extract_matching_criteria
      {
        child_age: @child.age,
        concerns: extract_concerns,
        primary_concerns: @child.primary_concerns,
        insurance_payer: @insurance.payer_name,
        insurance_verified: @insurance.eligibility_verified?,
        state: extract_state,
        assessment_scores: {
          phq_a: @assessment.phq_a_score,
          gad_7: @assessment.gad_7_score,
          combined: @assessment.score
        },
        preferred_language: extract_preferred_language,
        treatment_preferences: extract_treatment_preferences
      }
    end

    # Extract concerns from assessment and child data
    #
    # @return [Array<String>] List of concerns
    def extract_concerns
      concerns = []

      # From child's primary concerns
      if @child.primary_concerns.present?
        concerns << @child.primary_concerns
      end

      # From assessment summary
      if @assessment.summary.present?
        concerns << @assessment.summary
      end

      # From assessment responses (looking for high-scored items)
      phq_responses = @assessment.phq_a_responses
      gad_responses = @assessment.gad_7_responses

      # High PHQ-A scores suggest depression
      if @assessment.phq_a_score && @assessment.phq_a_score >= 10
        concerns << "depression symptoms"
      end

      # High GAD-7 scores suggest anxiety
      if @assessment.gad_7_score && @assessment.gad_7_score >= 10
        concerns << "anxiety symptoms"
      end

      concerns.compact.uniq
    end

    # Extract state from insurance or parent data
    #
    # @return [String, nil] State code
    def extract_state
      # Try to get from insurance payer name (often includes state)
      # e.g., "Anthem Blue Cross CA" -> "CA"
      if @insurance.payer_name =~ /\b([A-Z]{2})\b/
        return Regexp.last_match(1)
      end

      # Default to California for now (TODO: Get from parent address)
      "CA"
    end

    # Extract preferred language
    #
    # @return [String] Language preference (default: English)
    def extract_preferred_language
      # TODO: Add language preference to onboarding session
      "English"
    end

    # Extract treatment preferences
    #
    # @return [Hash] Treatment preferences
    def extract_treatment_preferences
      # TODO: Add treatment preferences to session progress
      {}
    end

    # Fetch candidate therapists with hard filters
    # AC2: Insurance acceptance (required filter), Age range fit
    #
    # @param criteria [Hash] Matching criteria
    # @return [Array<Therapist>] Filtered therapists
    def fetch_candidate_therapists(criteria)
      # Start with active therapists
      candidates = Therapist.active

      # Hard filter: Insurance acceptance
      candidates = filter_by_insurance(candidates, criteria[:insurance_payer])

      # Hard filter: State license (must be before age_range filter)
      candidates = filter_by_state_license(candidates, criteria[:state])

      # Eager load associations to avoid N+1 queries
      candidates = candidates.includes(
        :therapist_specializations,
        :therapist_insurance_panels,
        :therapist_availabilities,
        :therapist_time_offs
      )

      # Hard filter: Age range (converts to array, must be last)
      candidates = filter_by_age_range(candidates, criteria[:child_age])

      candidates
    end

    # Filter therapists by insurance acceptance
    #
    # @param therapists [ActiveRecord::Relation] Therapist query
    # @param insurance_payer [String] Insurance payer name
    # @return [ActiveRecord::Relation] Filtered therapists
    def filter_by_insurance(therapists, insurance_payer)
      return therapists unless insurance_payer

      therapists.joins(:therapist_insurance_panels)
                .where(therapist_insurance_panels: { insurance_name: insurance_payer })
                .distinct
    end

    # Filter therapists by age range
    #
    # @param therapists [ActiveRecord::Relation] Therapist query
    # @param child_age [Integer] Child's age
    # @return [Array<Therapist>] Filtered therapists (array not relation)
    def filter_by_age_range(therapists, child_age)
      return therapists unless child_age

      # Filter in memory since age_ranges is an array column
      # Load therapists to array first, then filter
      therapists.select { |t| t.serves_age?(child_age) }
    end

    # Filter therapists by state license
    #
    # @param therapists [ActiveRecord::Relation] Therapist query
    # @param state [String] State code
    # @return [ActiveRecord::Relation] Filtered therapists
    def filter_by_state_license(therapists, state)
      return therapists unless state

      therapists.where(license_state: state)
    end

    # Score therapists using weighted algorithm (AC2, AC3)
    #
    # @param therapists [ActiveRecord::Relation] Candidate therapists
    # @param criteria [Hash] Matching criteria
    # @return [Array<TherapistMatchResult>] Scored matches
    def score_therapists(therapists, criteria)
      therapists.map do |therapist|
        # Calculate component scores
        component_scores = {
          specialization: specialization_match_score(therapist, criteria),
          age_range: age_range_fit_score(therapist, criteria),
          availability: availability_score(therapist),
          treatment_modality: treatment_modality_score(therapist, criteria)
        }

        # Calculate final weighted score (0-100)
        final_score = calculate_final_score(component_scores)

        # Generate match reasoning (AC4, AC7)
        reasoning = generate_match_reasoning(therapist, component_scores, criteria)

        # Get next availability date
        next_availability = calculate_next_availability(therapist)

        TherapistMatchResult.new(
          therapist: therapist,
          score: final_score,
          component_scores: component_scores,
          reasoning: reasoning,
          next_availability: next_availability
        )
      end
    end

    # Calculate specialization match score using AI semantic matching
    # AC2: Specialization match to child's concerns (high weight)
    #
    # @param therapist [Therapist] Therapist to score
    # @param criteria [Hash] Matching criteria
    # @return [Float] Score 0.0-1.0
    def specialization_match_score(therapist, criteria)
      concerns = criteria[:concerns].join(" ")
      specializations = therapist.specializations

      return 0.0 if concerns.blank? || specializations.empty?

      # Try AI semantic matching first
      begin
        score = semantic_specialization_match(concerns, specializations)
        return score if score
      rescue StandardError => e
        Rails.logger.warn("AI semantic matching failed, falling back to keyword: #{e.message}")
      end

      # Fallback to keyword matching
      keyword_specialization_match(concerns, specializations)
    end

    # AI semantic matching of concerns to specializations
    #
    # @param concerns [String] Concatenated concerns
    # @param specializations [Array<String>] Therapist specializations
    # @return [Float, nil] Score 0.0-1.0 or nil on failure
    def semantic_specialization_match(concerns, specializations)
      cache_key = "semantic_match:#{Digest::MD5.hexdigest(concerns)}:#{specializations.sort.join(',')}"

      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        ai_client = Ai::Client.new

        prompt = build_semantic_matching_prompt(concerns, specializations)

        messages = [
          { role: "user", content: prompt }
        ]

        response = Timeout.timeout(AI_TIMEOUT_SECONDS) do
          ai_client.chat(messages: messages, context: { use_model: "claude-3-haiku-20240307" })
        end

        parse_semantic_score(response[:content])
      end
    rescue Timeout::Error, StandardError => e
      Rails.logger.error("Semantic matching error: #{e.message}")
      nil
    end

    # Build prompt for semantic matching
    #
    # @param concerns [String] Child concerns
    # @param specializations [Array<String>] Therapist specializations
    # @return [String] Prompt for AI
    def build_semantic_matching_prompt(concerns, specializations)
      <<~PROMPT
        You are analyzing whether a therapist's specializations match a child's mental health concerns.

        Child's concerns: #{concerns}

        Therapist's specializations: #{specializations.join(', ')}

        Rate how well this therapist's specializations match the child's concerns on a scale of 0.0 to 1.0:
        - 1.0: Perfect match, specializations directly address the concerns
        - 0.7-0.9: Strong match, specializations are highly relevant
        - 0.4-0.6: Moderate match, some overlap
        - 0.1-0.3: Weak match, limited relevance
        - 0.0: No match, specializations don't address concerns

        Consider semantic understanding:
        - "sad" and "depressed" relate to depression
        - "worried" and "nervous" relate to anxiety
        - "can't focus" and "distracted" relate to ADHD
        - "acting out" and "defiant" relate to behavioral issues

        Respond with ONLY a number between 0.0 and 1.0, nothing else.
      PROMPT
    end

    # Parse semantic score from AI response
    #
    # @param content [String] AI response content
    # @return [Float] Score 0.0-1.0
    def parse_semantic_score(content)
      # Extract first number from response
      match = content.match(/(\d+\.?\d*)/)
      return 0.0 unless match

      score = match[1].to_f
      # Clamp to 0.0-1.0 range
      [[score, 1.0].min, 0.0].max
    end

    # Keyword-based specialization matching (fallback)
    #
    # @param concerns [String] Concatenated concerns
    # @param specializations [Array<String>] Therapist specializations
    # @return [Float] Score 0.0-1.0
    def keyword_specialization_match(concerns, specializations)
      concerns_lower = concerns.downcase
      matches = 0

      # Keyword mappings
      mappings = {
        "anxiety" => ["anxiety", "worried", "nervous", "panic", "fear"],
        "depression" => ["depression", "sad", "hopeless", "down", "low mood"],
        "adhd" => ["adhd", "attention", "focus", "hyperactive", "impulsive"],
        "trauma" => ["trauma", "ptsd", "abuse", "neglect"],
        "behavioral issues" => ["behavior", "acting out", "defiant", "aggressive", "tantrums"]
      }

      specializations.each do |spec|
        spec_lower = spec.downcase
        keywords = mappings[spec_lower] || [spec_lower]

        if keywords.any? { |keyword| concerns_lower.include?(keyword) }
          matches += 1
        end
      end

      return 0.0 if specializations.empty?

      # Return proportion of specializations that match
      matches.to_f / specializations.length
    end

    # Calculate age range fit score
    # AC2: Age range fit (high weight)
    #
    # @param therapist [Therapist] Therapist to score
    # @param criteria [Hash] Matching criteria
    # @return [Float] Score 0.0-1.0
    def age_range_fit_score(therapist, criteria)
      child_age = criteria[:child_age]
      return 0.5 unless child_age # Neutral score if age unknown

      min_age = therapist.age_range_min
      max_age = therapist.age_range_max

      # If child is exactly in range, score 1.0
      if child_age >= min_age && child_age <= max_age
        # Give higher score if child is in the middle of the range
        range_width = max_age - min_age
        distance_from_min = child_age - min_age
        distance_from_max = max_age - child_age

        # Score higher if child is in middle 50% of range
        if distance_from_min >= range_width * 0.25 && distance_from_max >= range_width * 0.25
          1.0
        else
          0.9
        end
      else
        0.0 # Already filtered out, but just in case
      end
    end

    # Calculate availability score
    # AC2: Availability based on overlap with patient availability
    #
    # If patient has submitted availability, scores based on overlap count.
    # Otherwise, falls back to basic availability check.
    #
    # @param therapist [Therapist] Therapist to score
    # @return [Float] Score 0.0-1.0
    def availability_score(therapist)
      # If patient has submitted availability, use overlap scoring
      if patient_availabilities.any?
        return availability_overlap_score(therapist)
      end

      # Fallback: Score based on how soon therapist is available
      next_availability = calculate_next_availability(therapist)
      return 0.0 unless next_availability

      days_until_available = (next_availability - Date.today).to_i

      if days_until_available <= 7
        1.0
      elsif days_until_available <= 14
        0.5 + (0.5 * (14 - days_until_available) / 7.0)
      elsif days_until_available <= 30
        0.5 * (30 - days_until_available) / 16.0
      else
        0.0
      end
    end

    # Calculate availability overlap score with patient availability
    # Scores therapists based on how many overlapping time slots they have
    #
    # @param therapist [Therapist] Therapist to score
    # @return [Float] Score 0.0-1.0
    def availability_overlap_score(therapist)
      therapist_slots = therapist.therapist_availabilities.repeating
      return 0.0 if therapist_slots.empty?

      # Count overlapping time slots
      overlapping_count = 0

      patient_availabilities.each do |patient_slot|
        therapist_slots.each do |therapist_slot|
          overlapping_count += 1 if patient_slot.overlaps_with?(therapist_slot)
        end
      end

      # Score based on number of overlapping slots
      # More overlap = higher score
      case overlapping_count
      when 0 then 0.0       # No overlap - very low score (may filter out)
      when 1..2 then 0.4    # Few options
      when 3..5 then 0.6    # Reasonable options
      when 6..10 then 0.8   # Good options
      else 1.0              # Excellent options
      end
    end

    # Calculate next availability date for therapist
    #
    # @param therapist [Therapist] Therapist
    # @return [Date, nil] Next available date or nil
    def calculate_next_availability(therapist)
      # Check cache first
      cache_key = "therapist_availability:#{therapist.id}"
      cached = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
        @cache_misses += 1
        compute_next_availability(therapist)
      end

      @cache_hits += 1 if cached == Rails.cache.read(cache_key)
      cached
    end

    # Compute next availability (uncached)
    #
    # @param therapist [Therapist] Therapist
    # @return [Date, nil] Next available date or nil
    def compute_next_availability(therapist)
      # Get therapist's availability slots
      availabilities = therapist.therapist_availabilities.repeating

      return nil if availabilities.empty?

      # Find next occurrence of any availability slot
      # This is a simplified implementation - real version would check appointments
      # For now, assume next availability is within 7 days
      7.days.from_now.to_date
    end

    # Calculate treatment modality score
    # AC2: Treatment modality fit
    #
    # @param therapist [Therapist] Therapist to score
    # @param criteria [Hash] Matching criteria
    # @return [Float] Score 0.0-1.0
    def treatment_modality_score(therapist, criteria)
      # TODO: Implement when treatment modality preferences are added to session
      # For now, return neutral score
      0.5
    end

    # Calculate final weighted score (AC2, AC3)
    #
    # @param component_scores [Hash] Individual component scores
    # @return [Float] Final score 0-100
    def calculate_final_score(component_scores)
      weighted_sum = WEIGHTS.map do |component, weight|
        (component_scores[component] || 0.0) * weight
      end.sum

      # Convert to 0-100 scale
      weighted_sum * 100.0
    end

    # Generate match reasoning (AC4, AC7)
    #
    # @param therapist [Therapist] Matched therapist
    # @param component_scores [Hash] Component scores
    # @param criteria [Hash] Matching criteria
    # @return [String] Parent-friendly explanation
    def generate_match_reasoning(therapist, component_scores, criteria)
      reasons = []

      # Specialization reasoning
      if component_scores[:specialization] >= 0.7
        matching_specs = find_matching_specializations(therapist, criteria)
        if matching_specs.any?
          reasons << "Specializes in #{matching_specs.take(2).join(' and ')}"
        end
      end

      # Age range reasoning
      if component_scores[:age_range] >= 0.9
        reasons << "Experienced with children of this age"
      end

      # Availability reasoning
      if patient_availabilities.any?
        # Enhanced reasoning when patient availability is known
        if component_scores[:availability] >= 0.8
          reasons << "Has many times that match your schedule"
        elsif component_scores[:availability] >= 0.6
          reasons << "Has times that match your schedule"
        elsif component_scores[:availability] >= 0.4
          reasons << "Has some times that match your schedule"
        end
      else
        # Fallback reasoning when no patient availability
        if component_scores[:availability] >= 0.7
          reasons << "Available for appointments soon"
        elsif component_scores[:availability] >= 0.4
          reasons << "Available within 2 weeks"
        end
      end

      # Insurance reasoning
      reasons << "Accepts your insurance (#{criteria[:insurance_payer]})"

      # Combine into friendly sentence
      if reasons.empty?
        "This therapist meets your basic requirements."
      else
        reasons.join(". ") + "."
      end
    end

    # Find matching specializations for reasoning
    #
    # @param therapist [Therapist] Therapist
    # @param criteria [Hash] Matching criteria
    # @return [Array<String>] Matching specializations
    def find_matching_specializations(therapist, criteria)
      concerns = criteria[:concerns].join(" ").downcase
      specializations = therapist.specializations

      mappings = {
        "anxiety" => ["anxiety", "worried", "nervous"],
        "depression" => ["depression", "sad", "depressed"],
        "adhd" => ["adhd", "attention", "focus"],
        "trauma" => ["trauma", "ptsd"],
        "behavioral issues" => ["behavior", "acting out"]
      }

      matching = []
      specializations.each do |spec|
        spec_lower = spec.downcase
        keywords = mappings[spec_lower] || [spec_lower]

        if keywords.any? { |keyword| concerns.include?(keyword) }
          matching << spec
        end
      end

      matching
    end

    # Store match results for analytics
    #
    # @param matches [Array<TherapistMatchResult>] Match results
    # @param criteria [Hash] Matching criteria
    # @return [void]
    def store_match_results(matches, criteria)
      processing_time = ((Time.current - @start_time) * 1000).to_i

      TherapistMatch.create!(
        onboarding_session_id: @session_id,
        matched_therapists: matches.map(&:to_h),
        criteria_used: criteria,
        processing_time_ms: processing_time
      )
    rescue StandardError => e
      Rails.logger.error("Failed to store match results: #{e.message}")
      # Don't fail matching if analytics storage fails
    end

    # Fetch cached match results
    #
    # @return [Array<TherapistMatchResult>, nil] Cached results or nil
    def fetch_cached_result
      cache_key = "match_result:#{session_id}"
      Rails.cache.read(cache_key)
    end

    # Cache match results
    #
    # @param matches [Array<TherapistMatchResult>] Matches to cache
    # @return [void]
    def cache_match_results(matches)
      cache_key = "match_result:#{session_id}"
      Rails.cache.write(cache_key, matches, expires_in: 10.minutes)
    end
  end
end
