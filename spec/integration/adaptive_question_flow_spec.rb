# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Adaptive Question Flow', type: :integration do
  let(:session) { create(:onboarding_session) }
  let(:context_manager) { Ai::ContextManager.new(session_id: session.id) }

  describe 'Full conversation flow through all phases' do
    it 'progresses through welcome -> parent_info -> child_info -> concerns' do
      # Phase 1: Welcome (no required fields, auto-transitions)
      expect(context_manager.current_phase).to eq('welcome')
      expect(context_manager.can_transition_phase?).to be true

      context_manager.transition_to_next_phase

      # Phase 2: Parent Info
      expect(context_manager.current_phase).to eq('parent_info')
      expect(context_manager.can_transition_phase?).to be false

      # Collect parent information
      context_manager.mark_field_collected('parent_first_name')
      expect(context_manager.can_transition_phase?).to be false # Still need email

      context_manager.mark_field_collected('parent_email')
      expect(context_manager.can_transition_phase?).to be true

      context_manager.transition_to_next_phase

      # Phase 3: Child Info
      expect(context_manager.current_phase).to eq('child_info')

      context_manager.mark_field_collected('child_first_name')
      context_manager.mark_field_collected('child_last_name')
      context_manager.mark_field_collected('child_date_of_birth')
      context_manager.transition_to_next_phase

      # Phase 4: Concerns
      expect(context_manager.current_phase).to eq('concerns')

      context_manager.mark_field_collected('primary_concern')

      # Progress should be 100%
      expect(context_manager.calculate_progress_percentage).to eq(100)
    end
  end

  describe 'No question repetition' do
    it 'does not generate questions for already collected fields' do
      # Move to parent_info phase
      context_manager.transition_to_next_phase

      # Collect parent name
      context_manager.mark_field_collected('parent_first_name')

      # Generate follow-ups
      questions = context_manager.generate_follow_ups

      # Should not ask for name again, but should ask for email
      expect(questions.any? { |q| q.match?(/name/i) }).to be false
      expect(questions.any? { |q| q.match?(/email/i) }).to be true
    end

    it 'prevents duplicate field collection' do
      context_manager.mark_field_collected('parent_email')
      context_manager.mark_field_collected('parent_email')
      context_manager.mark_field_collected('parent_email')

      expect(context_manager.collected_fields.count('parent_email')).to eq(1)
    end
  end

  describe 'Response analysis and adaptive follow-ups' do
    context 'with complete response' do
      let(:complete_response) { 'My name is Sarah Johnson and my email is sarah@example.com' }

      it 'detects completeness and extracts fields' do
        analysis = context_manager.analyze_response(complete_response)

        expect(analysis[:is_complete]).to be true
        expect(analysis[:needs_clarification]).to be false
        expect(analysis[:extracted_fields]).to include('parent_email')
      end

      it 'marks extracted fields as collected' do
        context_manager.update_from_response(complete_response, 'Thank you!')

        expect(context_manager.field_collected?('parent_email')).to be true
      end
    end

    context 'with ambiguous response' do
      let(:ambiguous_response) { "I'm not sure, maybe I could..." }

      it 'detects ambiguity and needs clarification' do
        analysis = context_manager.analyze_response(ambiguous_response)

        expect(analysis[:is_ambiguous]).to be true
        expect(analysis[:needs_clarification]).to be true
      end
    end

    context 'with incomplete response' do
      let(:incomplete_response) { 'Um...' }

      it 'detects incompleteness' do
        analysis = context_manager.analyze_response(incomplete_response)

        expect(analysis[:is_complete]).to be false
        expect(analysis[:needs_clarification]).to be true
      end
    end
  end

  describe 'Progress tracking' do
    it 'updates progress percentage as fields are collected' do
      expect(context_manager.calculate_progress_percentage).to eq(0)

      # Total: 6 fields (parent_first_name, parent_email, child_first_name, child_last_name, child_date_of_birth, primary_concern)
      context_manager.mark_field_collected('parent_first_name')
      expect(context_manager.calculate_progress_percentage).to eq(17)

      context_manager.mark_field_collected('parent_email')
      expect(context_manager.calculate_progress_percentage).to eq(33)

      context_manager.mark_field_collected('child_first_name')
      expect(context_manager.calculate_progress_percentage).to eq(50)

      context_manager.mark_field_collected('child_last_name')
      expect(context_manager.calculate_progress_percentage).to eq(67)

      context_manager.mark_field_collected('child_date_of_birth')
      expect(context_manager.calculate_progress_percentage).to eq(83)

      context_manager.mark_field_collected('primary_concern')
      expect(context_manager.calculate_progress_percentage).to eq(100)
    end

    it 'reflects progress in session' do
      context_manager.mark_field_collected('parent_first_name')
      context_manager.update_from_response('test', 'test')

      session.reload
      expect(session.progress['percentage']).to eq(17)
    end
  end

  describe 'Context building with adaptive flow' do
    before do
      context_manager.transition_to_next_phase # Move to parent_info
      context_manager.mark_field_collected('parent_first_name')
      context_manager.mark_field_collected('parent_email')
    end

    it 'includes progress information in context' do
      messages = context_manager.build_context

      progress_message = messages.find { |m| m[:role] == 'system' && m[:content].include?('Progress') }

      expect(progress_message).to be_present
      expect(progress_message[:content]).to include('parent_info')
      expect(progress_message[:content]).to include('parent_first_name')
      expect(progress_message[:content]).to include('parent_email')
    end

    it 'provides missing fields information to AI' do
      messages = context_manager.build_context

      progress_message = messages.find { |m| m[:role] == 'system' && m[:content].include?('Progress') }

      # Parent info complete, so child info should be needed
      context_manager.transition_to_next_phase
      messages = context_manager.build_context

      progress_message = messages.find { |m| m[:role] == 'system' && m[:content].include?('Progress') }
      expect(progress_message[:content]).to include('child_info')
    end
  end

  describe 'Conversation state persistence' do
    it 'persists context manager state to session progress' do
      context_manager.mark_field_collected('parent_email')
      context_manager.add_pending_question('What is your phone?')
      context_manager.transition_to_next_phase

      session.reload
      saved_state = session.progress['context_manager']

      expect(saved_state['phase']).to eq('parent_info')
      expect(saved_state['collected_fields']).to include('parent_email')
      expect(saved_state['pending_questions']).to include('What is your phone?')
    end

    it 'loads existing state when context manager is recreated' do
      context_manager.mark_field_collected('parent_email')
      context_manager.transition_to_next_phase

      # Create new context manager for same session
      new_context_manager = Ai::ContextManager.new(session_id: session.id)

      expect(new_context_manager.current_phase).to eq('parent_info')
      expect(new_context_manager.collected_fields).to include('parent_email')
    end
  end

  describe 'Missing information detection' do
    before do
      context_manager.transition_to_next_phase # Move to parent_info
    end

    it 'identifies missing required fields for current phase' do
      questions = context_manager.generate_follow_ups

      # Should ask for both parent_first_name and parent_email
      expect(questions.length).to be >= 2
    end

    it 'stops asking for fields once collected' do
      context_manager.mark_field_collected('parent_first_name')

      questions = context_manager.generate_follow_ups

      # Should only ask for email now, not name
      name_questions = questions.count { |q| q.match?(/name/i) }
      email_questions = questions.count { |q| q.match?(/email/i) }

      expect(name_questions).to eq(0)
      expect(email_questions).to be >= 1
    end
  end

  describe 'Field extraction from natural language' do
    it 'extracts email addresses from responses' do
      response = 'You can reach me at sarah.johnson@example.com'
      analysis = context_manager.analyze_response(response)

      expect(analysis[:extracted_fields]).to have_key('parent_email')
      expect(analysis[:extracted_fields]['parent_email'][:confidence]).to eq('high')
    end

    it 'extracts phone numbers from responses' do
      response = 'My number is 555-123-4567'
      analysis = context_manager.analyze_response(response)

      expect(analysis[:extracted_fields]).to have_key('parent_phone')
    end

    it 'extracts names from introductions' do
      response = "Hi, I'm Sarah"
      analysis = context_manager.analyze_response(response)

      expect(analysis[:extracted_fields]).to have_key('parent_first_name')
      expect(analysis[:extracted_fields]['parent_first_name'][:confidence]).to eq('medium')
    end
  end
end
