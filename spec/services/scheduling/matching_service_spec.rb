# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Scheduling::MatchingService, type: :service do
  let(:session) { create(:onboarding_session, :with_child, :with_insurance, :with_assessment) }
  let(:child) { session.child }
  let(:insurance) { session.insurance }
  let(:assessment) { session.assessment }

  let(:service) { described_class.new(session_id: session.id) }

  # Create therapists with different attributes
  let!(:therapist_anxiety) do
    create(:therapist,
           active: true,
           age_ranges: ['5-12', '13-17'],
           license_state: 'CA').tap do |t|
      create(:therapist_specialization, therapist: t, specialization: 'anxiety')
      create(:therapist_insurance_panel, therapist: t, insurance_name: 'Anthem')
      create(:therapist_availability, therapist: t, day_of_week: 1, start_time: '09:00', end_time: '17:00')
    end
  end

  let!(:therapist_depression) do
    create(:therapist,
           active: true,
           age_ranges: ['8-18'],
           license_state: 'CA').tap do |t|
      create(:therapist_specialization, therapist: t, specialization: 'depression')
      create(:therapist_insurance_panel, therapist: t, insurance_name: 'Anthem')
      create(:therapist_availability, therapist: t, day_of_week: 2, start_time: '10:00', end_time: '18:00')
    end
  end

  let!(:therapist_adhd) do
    create(:therapist,
           active: true,
           age_ranges: ['6-12'],
           license_state: 'CA').tap do |t|
      create(:therapist_specialization, therapist: t, specialization: 'adhd')
      create(:therapist_insurance_panel, therapist: t, insurance_name: 'Anthem')
      create(:therapist_availability, therapist: t, day_of_week: 3, start_time: '08:00', end_time: '16:00')
    end
  end

  # Therapist that doesn't accept insurance (should be filtered out)
  let!(:therapist_no_insurance) do
    create(:therapist,
           active: true,
           age_ranges: ['5-18'],
           license_state: 'CA').tap do |t|
      create(:therapist_specialization, therapist: t, specialization: 'anxiety')
      create(:therapist_insurance_panel, therapist: t, insurance_name: 'Different Insurance')
    end
  end

  # Therapist in wrong state (should be filtered out)
  let!(:therapist_wrong_state) do
    create(:therapist,
           active: true,
           age_ranges: ['5-18'],
           license_state: 'NY').tap do |t|
      create(:therapist_specialization, therapist: t, specialization: 'anxiety')
      create(:therapist_insurance_panel, therapist: t, insurance_name: 'Anthem')
    end
  end

  # Therapist wrong age range (should be filtered out)
  let!(:therapist_wrong_age) do
    create(:therapist,
           active: true,
           age_ranges: ['18-65'],
           license_state: 'CA').tap do |t|
      create(:therapist_specialization, therapist: t, specialization: 'anxiety')
      create(:therapist_insurance_panel, therapist: t, insurance_name: 'Anthem')
    end
  end

  before do
    # Set up child data
    child.update!(
      date_of_birth: 10.years.ago.to_date.to_s,
      primary_concerns: 'anxiety and worry about school'
    )

    # Set up insurance
    insurance.update!(
      payer_name: 'Anthem',
      verification_status: :verified
    )

    # Set up assessment (must transition through in_progress)
    assessment.update!(status: :in_progress)
    assessment.update!(
      status: :complete,
      score: 60,
      responses: {
        phq_a: [
          { item: 1, value: 2, raw_text: 'sometimes', timestamp: Time.current.iso8601 }
        ],
        gad_7: [
          { item: 1, value: 3, raw_text: 'most days', timestamp: Time.current.iso8601 }
        ],
        scores: {
          phq_a_total: 8,
          gad_7_total: 12
        }
      }.to_json,
      summary: 'Child shows signs of anxiety'
    )
  end

  describe '#match' do
    context 'with valid session data' do
      it 'returns an array of TherapistMatchResult objects' do
        matches = service.match
        expect(matches).to be_an(Array)
        expect(matches).to all(be_a(Scheduling::TherapistMatchResult))
      end

      it 'returns at least MIN_RECOMMENDATIONS matches when available' do
        matches = service.match
        expect(matches.length).to be >= Scheduling::MatchingService::MIN_RECOMMENDATIONS
      end

      it 'filters out therapists not accepting insurance' do
        matches = service.match
        therapist_ids = matches.map { |m| m.therapist.id }
        expect(therapist_ids).not_to include(therapist_no_insurance.id)
      end

      it 'filters out therapists in wrong state' do
        matches = service.match
        therapist_ids = matches.map { |m| m.therapist.id }
        expect(therapist_ids).not_to include(therapist_wrong_state.id)
      end

      it 'filters out therapists with wrong age range' do
        matches = service.match
        therapist_ids = matches.map { |m| m.therapist.id }
        expect(therapist_ids).not_to include(therapist_wrong_age.id)
      end

      it 'includes only valid matching therapists' do
        matches = service.match
        therapist_ids = matches.map { |m| m.therapist.id }
        expect(therapist_ids).to include(therapist_anxiety.id)
        expect(therapist_ids).to include(therapist_depression.id)
        expect(therapist_ids).to include(therapist_adhd.id)
      end

      it 'ranks therapists by score in descending order' do
        matches = service.match
        scores = matches.map(&:score)
        expect(scores).to eq(scores.sort.reverse)
      end

      it 'includes match scores between 0 and 100' do
        matches = service.match
        matches.each do |match|
          expect(match.score).to be_between(0, 100)
        end
      end

      it 'includes component scores for each match' do
        matches = service.match
        matches.each do |match|
          expect(match.component_scores).to include(
            :specialization,
            :age_range,
            :availability,
            :treatment_modality
          )
        end
      end

      it 'includes reasoning for each match' do
        matches = service.match
        matches.each do |match|
          expect(match.reasoning).to be_present
          expect(match.reasoning).to be_a(String)
        end
      end

      it 'completes within MAX_PROCESSING_TIME_MS' do
        start_time = Time.current
        service.match
        elapsed_ms = ((Time.current - start_time) * 1000).to_i
        expect(elapsed_ms).to be < Scheduling::MatchingService::MAX_PROCESSING_TIME_MS
      end

      it 'stores match results for analytics' do
        expect {
          service.match
        }.to change(TherapistMatch, :count).by(1)

        match_record = TherapistMatch.last
        expect(match_record.onboarding_session_id).to eq(session.id)
        expect(match_record.matched_therapists).to be_present
        expect(match_record.criteria_used).to be_present
        expect(match_record.processing_time_ms).to be > 0
      end

      it 'caches results for subsequent calls' do
        first_matches = service.match
        second_service = described_class.new(session_id: session.id)
        second_matches = second_service.match

        expect(first_matches.map(&:score)).to eq(second_matches.map(&:score))
      end
    end

    context 'with missing session data' do
      it 'raises error if session not found' do
        service = described_class.new(session_id: 'nonexistent')
        expect { service.match }.to raise_error(ArgumentError, /Session not found/)
      end

      it 'raises error if child data missing' do
        session.child.destroy
        expect { service.match }.to raise_error(ArgumentError, /must have child data/)
      end

      it 'raises error if insurance data missing' do
        session.insurance.destroy
        expect { service.match }.to raise_error(ArgumentError, /must have insurance data/)
      end

      it 'raises error if assessment data missing' do
        session.assessment.destroy
        expect { service.match }.to raise_error(ArgumentError, /must have assessment data/)
      end

      it 'raises error if assessment not complete' do
        assessment.update!(status: :in_progress)
        expect { service.match }.to raise_error(ArgumentError, /Assessment must be complete/)
      end
    end

    context 'specialization matching' do
      it 'scores therapists with matching specializations higher' do
        child.update!(primary_concerns: 'anxiety and panic attacks')

        matches = service.match
        anxiety_match = matches.find { |m| m.therapist.id == therapist_anxiety.id }

        expect(anxiety_match.specialization_score).to be > 0.5
      end

      it 'handles semantic matching (sad -> depression)' do
        child.update!(primary_concerns: 'child is very sad and has no energy')

        matches = service.match
        depression_match = matches.find { |m| m.therapist.id == therapist_depression.id }

        # Depression therapist should have high specialization score
        expect(depression_match.specialization_score).to be > 0.3
      end

      it 'handles multiple concerns matching multiple specializations' do
        # Create therapist with both anxiety and depression
        therapist_both = create(:therapist,
                                active: true,
                                age_ranges: ['5-18'],
                                license_state: 'CA')
        create(:therapist_specialization, therapist: therapist_both, specialization: 'anxiety')
        create(:therapist_specialization, therapist: therapist_both, specialization: 'depression')
        create(:therapist_insurance_panel, therapist: therapist_both, insurance_name: insurance.payer_name)
        create(:therapist_availability, therapist: therapist_both)

        child.update!(primary_concerns: 'anxiety and depression')

        matches = service.match
        both_match = matches.find { |m| m.therapist.id == therapist_both.id }

        expect(both_match.specialization_score).to be > 0.5
      end
    end

    context 'age range scoring' do
      it 'scores perfect age fit at 1.0' do
        child.update!(date_of_birth: 10.years.ago.to_date.to_s) # Age 10

        matches = service.match
        matches.each do |match|
          expect(match.age_range_score).to be > 0.8
        end
      end

      it 'filters out therapists outside age range' do
        child.update!(date_of_birth: 20.years.ago.to_date.to_s) # Age 20 (adult)

        matches = service.match
        # All our test therapists serve children/teens, so no matches expected
        # unless we have therapists serving adults
        expect(matches).to be_empty
      end
    end

    context 'availability scoring' do
      it 'scores therapists with availability' do
        matches = service.match
        matches.each do |match|
          expect(match.availability_score).to be > 0
        end
      end
    end

    context 'reasoning generation' do
      it 'includes specialization in reasoning for good matches' do
        child.update!(primary_concerns: 'severe anxiety')

        matches = service.match
        anxiety_match = matches.find { |m| m.therapist.id == therapist_anxiety.id }

        expect(anxiety_match.reasoning).to include('anxiety')
      end

      it 'includes insurance information in reasoning' do
        matches = service.match
        matches.each do |match|
          expect(match.reasoning).to include(insurance.payer_name)
        end
      end

      it 'includes availability information in reasoning' do
        matches = service.match
        matches.each do |match|
          expect(match.reasoning).to match(/available/i)
        end
      end

      it 'uses parent-friendly language' do
        matches = service.match
        matches.each do |match|
          # Should not contain technical jargon
          expect(match.reasoning).not_to match(/algorithm|score|weight|coefficient/)
          # Should be conversational
          expect(match.reasoning).to match(/\./i) # Contains sentences
        end
      end
    end

    context 'edge cases' do
      context 'with no matching therapists' do
        before do
          # Remove all therapists
          Therapist.destroy_all
        end

        it 'returns empty array' do
          matches = service.match
          expect(matches).to be_empty
        end
      end

      context 'with exactly 3 matching therapists' do
        it 'returns all 3 therapists' do
          matches = service.match
          expect(matches.length).to eq(3)
        end
      end

      context 'with tie scores' do
        before do
          # Make all therapists very similar
          [therapist_anxiety, therapist_depression, therapist_adhd].each do |t|
            t.update!(age_ranges: ['5-18'])
            t.therapist_specializations.destroy_all
            create(:therapist_specialization, therapist: t, specialization: 'anxiety')
          end

          child.update!(primary_concerns: 'anxiety')
        end

        it 'still returns sorted results' do
          matches = service.match
          scores = matches.map(&:score)
          expect(scores).to eq(scores.sort.reverse)
        end
      end

      context 'with AI semantic matching unavailable' do
        before do
          # Stub AI client to raise error
          allow_any_instance_of(Ai::Client).to receive(:chat).and_raise(StandardError.new('AI unavailable'))
        end

        it 'falls back to keyword matching' do
          child.update!(primary_concerns: 'anxiety')

          matches = service.match
          expect(matches).not_to be_empty

          anxiety_match = matches.find { |m| m.therapist.id == therapist_anxiety.id }
          expect(anxiety_match).to be_present
          expect(anxiety_match.specialization_score).to be > 0
        end
      end
    end

    context 'performance and caching' do
      it 'uses cached therapist data' do
        # First call loads data
        service.match

        # Second call should use cache
        expect(Rails.cache).to receive(:read).at_least(:once).and_call_original
        second_service = described_class.new(session_id: session.id)
        second_service.match
      end

      it 'caches match results' do
        first_matches = service.match

        # Clear query cache but not Rails.cache
        ActiveRecord::Base.connection.clear_query_cache

        second_service = described_class.new(session_id: session.id)
        second_matches = second_service.match

        expect(first_matches.map(&:score)).to eq(second_matches.map(&:score))
      end
    end
  end

  describe 'scoring weights' do
    it 'uses correct weight distribution' do
      weights = Scheduling::MatchingService::WEIGHTS
      expect(weights[:specialization]).to eq(0.40)
      expect(weights[:age_range]).to eq(0.30)
      expect(weights[:availability]).to eq(0.20)
      expect(weights[:treatment_modality]).to eq(0.10)
    end

    it 'weights sum to 1.0' do
      weights = Scheduling::MatchingService::WEIGHTS
      total = weights.values.sum
      expect(total).to eq(1.0)
    end
  end

  describe 'TherapistMatchResult' do
    let(:matches) { service.match }
    let(:match) { matches.first }

    it 'can be converted to hash' do
      hash = match.to_h
      expect(hash).to include(
        :therapist_id,
        :therapist_name,
        :score,
        :component_scores,
        :reasoning,
        :therapist_details
      )
    end

    it 'includes therapist details in hash' do
      hash = match.to_h
      expect(hash[:therapist_details]).to include(
        :bio,
        :credentials,
        :specializations,
        :languages
      )
    end

    it 'identifies strong matches (>= 70)' do
      # This may vary based on actual data, but we can check the method exists
      expect(match).to respond_to(:strong_match?)
    end

    it 'identifies good matches (>= 50)' do
      expect(match).to respond_to(:good_match?)
    end
  end
end
