# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Support::IntercomContextService do
  let(:session) { create(:onboarding_session, status: :in_progress) }
  let(:parent) { create(:parent, onboarding_session: session, first_name: 'Jane', last_name: 'Doe') }
  let(:child) { create(:child, onboarding_session: session, date_of_birth: '2012-05-15') }
  let(:insurance) { create(:insurance, onboarding_session: session, verification_status: :pending) }
  let(:admin_url) { 'https://admin.daybreak.health' }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ADMIN_DASHBOARD_URL').and_return(admin_url)
  end

  describe '#initialize' do
    it 'initializes with a session_id' do
      service = described_class.new(session_id: session.id)
      expect(service.session_id).to eq(session.id)
    end

    it 'raises error when session_id is blank' do
      expect {
        described_class.new(session_id: '')
      }.to raise_error(ArgumentError, 'session_id cannot be blank')
    end

    it 'raises error when session_id is nil' do
      expect {
        described_class.new(session_id: nil)
      }.to raise_error(ArgumentError, 'session_id cannot be blank')
    end
  end

  describe '#call' do
    subject(:result) { described_class.new(session_id: session.id).call }

    context 'with complete session data' do
      before do
        parent
        child
        insurance
      end

      it 'returns a context payload hash' do
        expect(result).to be_a(Hash)
        expect(result.keys).to match_array([
          :session_id,
          :onboarding_phase,
          :parent_first_name,
          :child_age,
          :insurance_status,
          :has_errors,
          :error_type,
          :admin_link
        ])
      end

      it 'includes the session ID' do
        expect(result[:session_id]).to eq(session.id)
      end

      it 'includes the onboarding phase' do
        expect(result[:onboarding_phase]).to eq('in_progress')
      end

      it 'includes parent first name only (no last name)' do
        expect(result[:parent_first_name]).to eq('Jane')
        expect(result.to_s).not_to include('Doe')
      end

      it 'includes child age (not DOB)' do
        # Child born 2012-05-15, age should be ~12 years
        expect(result[:child_age]).to be_a(Integer)
        expect(result[:child_age]).to be >= 11
        expect(result[:child_age]).to be <= 13
        expect(result.to_s).not_to include('2012-05-15')
      end

      it 'includes insurance status enum' do
        expect(result[:insurance_status]).to eq('pending')
      end

      it 'includes has_errors flag' do
        expect(result[:has_errors]).to be false
      end

      it 'includes error_type as nil when no errors' do
        expect(result[:error_type]).to be_nil
      end

      it 'includes admin deep link' do
        expect(result[:admin_link]).to eq("#{admin_url}/sessions/#{session.id}")
      end
    end

    context 'with minimal session data' do
      it 'returns context with nil values for missing data' do
        expect(result[:session_id]).to eq(session.id)
        expect(result[:parent_first_name]).to be_nil
        expect(result[:child_age]).to be_nil
        expect(result[:insurance_status]).to be_nil
      end
    end

    context 'when session not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.new(session_id: 'nonexistent-id').call
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'onboarding phase extraction' do
      it 'returns status as string' do
        session.update!(status: :insurance_pending)
        expect(result[:onboarding_phase]).to eq('insurance_pending')
      end

      it 'handles different statuses' do
        # Test each status with a new session to avoid state machine transition issues
        statuses = %i[started in_progress insurance_pending assessment_complete submitted]
        statuses.each do |status|
          test_session = create(:onboarding_session, status: status)
          result = described_class.new(session_id: test_session.id).call
          expect(result[:onboarding_phase]).to eq(status.to_s)
        end
      end
    end

    describe 'parent first name extraction' do
      context 'when parent exists' do
        before { parent }

        it 'returns decrypted first name' do
          expect(result[:parent_first_name]).to eq('Jane')
        end
      end

      context 'when parent does not exist' do
        it 'returns nil' do
          expect(result[:parent_first_name]).to be_nil
        end
      end
    end

    describe 'child age extraction' do
      context 'when child exists with valid DOB' do
        before { child }

        it 'returns calculated age' do
          expect(result[:child_age]).to be_a(Integer)
          expect(result[:child_age]).to be > 0
        end

        it 'uses Child model age calculation' do
          expected_age = child.age
          expect(result[:child_age]).to eq(expected_age)
        end
      end

      context 'when child does not exist' do
        it 'returns nil' do
          expect(result[:child_age]).to be_nil
        end
      end

      context 'when child exists but DOB is blank' do
        it 'returns nil' do
          # Create a child and stub the Child class's age method to return nil
          test_child = create(:child, onboarding_session: session)
          allow_any_instance_of(Child).to receive(:age).and_return(nil)

          result = described_class.new(session_id: session.id).call
          expect(result[:child_age]).to be_nil
        end
      end
    end

    describe 'insurance status extraction' do
      before { insurance }

      it 'returns verification_status enum for pending' do
        insurance.update!(verification_status: :pending)
        expect(result[:insurance_status]).to eq('pending')
      end

      it 'returns verification_status enum for verified' do
        insurance.update!(verification_status: :verified)
        expect(result[:insurance_status]).to eq('verified')
      end

      it 'returns verification_status enum for failed' do
        insurance.update!(verification_status: :failed)
        expect(result[:insurance_status]).to eq('failed')
      end

      it 'returns verification_status enum for self_pay' do
        insurance.update!(verification_status: :self_pay)
        expect(result[:insurance_status]).to eq('self_pay')
      end

      context 'when insurance does not exist' do
        before { session.insurance&.destroy }

        it 'returns nil' do
          expect(result[:insurance_status]).to be_nil
        end
      end
    end

    describe 'error detection' do
      context 'with expired session' do
        before { session.update!(status: :expired) }

        it 'detects error' do
          expect(result[:has_errors]).to be true
          expect(result[:error_type]).to eq('session_expired')
        end
      end

      context 'with abandoned session' do
        before { session.update!(status: :abandoned) }

        it 'detects error' do
          expect(result[:has_errors]).to be true
          expect(result[:error_type]).to eq('session_abandoned')
        end
      end

      context 'with OCR extraction failed' do
        before do
          insurance
          insurance.update!(
            verification_result: {
              'error' => {
                'code' => 'OCR_FAILED',
                'message' => 'Unable to extract text'
              }
            }
          )
        end

        it 'detects error' do
          expect(result[:has_errors]).to be true
          expect(result[:error_type]).to eq('ocr_extraction_failed')
        end
      end

      context 'with eligibility verification failed' do
        before do
          insurance
          insurance.update!(verification_status: :failed)
        end

        it 'detects error' do
          expect(result[:has_errors]).to be true
          expect(result[:error_type]).to eq('eligibility_verification_failed')
        end
      end

      context 'with eligibility needs review' do
        before do
          insurance
          insurance.update!(verification_status: :manual_review)
        end

        it 'detects error' do
          expect(result[:has_errors]).to be true
          expect(result[:error_type]).to eq('eligibility_needs_review')
        end
      end

      context 'with missing insurance fields' do
        before do
          insurance
          insurance.update!(
            verification_status: :ocr_complete,
            payer_name: nil,
            member_id: nil
          )
        end

        it 'detects error' do
          expect(result[:has_errors]).to be true
          expect(result[:error_type]).to eq('missing_required_fields')
        end
      end

      context 'with no errors' do
        before do
          parent
          child
          insurance
        end

        it 'reports no errors' do
          expect(result[:has_errors]).to be false
          expect(result[:error_type]).to be_nil
        end
      end
    end

    describe 'admin link generation' do
      it 'uses ADMIN_DASHBOARD_URL from environment' do
        expect(result[:admin_link]).to start_with(admin_url)
      end

      it 'includes session ID in URL' do
        expect(result[:admin_link]).to include(session.id)
      end

      it 'follows the pattern /sessions/{session_id}' do
        expect(result[:admin_link]).to eq("#{admin_url}/sessions/#{session.id}")
      end

      context 'when ADMIN_DASHBOARD_URL is not set' do
        before do
          allow(ENV).to receive(:[]).with('ADMIN_DASHBOARD_URL').and_return(nil)
        end

        it 'uses default admin URL' do
          expect(result[:admin_link]).to start_with('https://admin.daybreak.health')
        end
      end
    end
  end

  describe '.call' do
    before do
      parent
      child
      insurance
    end

    it 'is a class method convenience wrapper' do
      result = described_class.call(session_id: session.id)
      expect(result).to be_a(Hash)
      expect(result[:session_id]).to eq(session.id)
    end
  end

  describe 'HIPAA compliance and PHI sanitization' do
    before do
      parent
      child
      # Update without validation since we're testing PHI sanitization, not validation
      insurance.update_columns(
        payer_name: 'Blue Cross',
        member_id: 'ABC123456',
        group_number: 'GRP999',
        subscriber_name: 'Jane Doe',
        subscriber_dob: '1980-01-01'
      )
    end

    subject(:result) { described_class.new(session_id: session.id).call }

    it 'includes only PHI-safe data' do
      # PHI-SAFE: session_id, first_name only, age (not DOB), status enums
      expect(result[:session_id]).to be_present
      expect(result[:parent_first_name]).to eq('Jane')
      expect(result[:child_age]).to be_a(Integer)
      expect(result[:insurance_status]).to eq('pending')
    end

    it 'does NOT include last names' do
      expect(result.to_s).not_to include('Doe')
      expect(result.keys).not_to include(:parent_last_name, :last_name)
    end

    it 'does NOT include emails' do
      expect(result.keys).not_to include(:email, :parent_email)
    end

    it 'does NOT include phone numbers' do
      expect(result.keys).not_to include(:phone, :parent_phone)
    end

    it 'does NOT include date of birth' do
      expect(result.to_s).not_to include('2012-05-15')
      expect(result.to_s).not_to include('1980-01-01')
      expect(result.keys).not_to include(:dob, :date_of_birth, :subscriber_dob)
    end

    it 'does NOT include insurance member IDs' do
      expect(result.to_s).not_to include('ABC123456')
      expect(result.keys).not_to include(:member_id)
    end

    it 'does NOT include insurance group numbers' do
      expect(result.to_s).not_to include('GRP999')
      expect(result.keys).not_to include(:group_number)
    end

    it 'does NOT include subscriber names' do
      expect(result.keys).not_to include(:subscriber_name)
    end

    it 'does NOT include policy numbers' do
      expect(result.keys).not_to include(:policy_number)
    end

    it 'includes only age, not DOB' do
      expect(result[:child_age]).to be_a(Integer)
      expect(result.to_s).not_to match(/\d{4}-\d{2}-\d{2}/)
    end

    it 'includes only status enums, not detailed info' do
      expect(result[:insurance_status]).to eq('pending')
      expect(result.to_s).not_to include('Blue Cross')
    end
  end

  describe 'integration with actual models' do
    it 'works with real parent encryption' do
      parent = create(:parent,
        onboarding_session: session,
        first_name: 'TestFirst',
        last_name: 'TestLast'
      )

      result = described_class.new(session_id: session.id).call
      expect(result[:parent_first_name]).to eq('TestFirst')
    end

    it 'works with real child age calculation' do
      child = create(:child,
        onboarding_session: session,
        date_of_birth: 10.years.ago.to_date.to_s
      )

      result = described_class.new(session_id: session.id).call
      expect(result[:child_age]).to eq(10)
    end

    it 'works with all insurance statuses' do
      insurance = create(:insurance, onboarding_session: session)

      Insurance.verification_statuses.keys.each do |status|
        insurance.update!(verification_status: status)
        result = described_class.new(session_id: session.id).call
        expect(result[:insurance_status]).to eq(status.to_s)
      end
    end
  end
end
