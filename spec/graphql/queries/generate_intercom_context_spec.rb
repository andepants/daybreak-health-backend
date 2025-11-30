# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'generateIntercomContext query', type: :graphql do
  let(:session) { create(:onboarding_session, status: :in_progress) }
  let(:session_id_prefixed) { "sess_#{session.id.gsub('-', '')}" }
  let(:admin_url) { 'https://admin.daybreak.health' }

  let(:query) do
    <<~GQL
      query GenerateIntercomContext($sessionId: ID!) {
        generateIntercomContext(sessionId: $sessionId) {
          sessionId
          onboardingPhase
          parentFirstName
          childAge
          insuranceStatus
          hasErrors
          errorType
          adminLink
        }
      }
    GQL
  end

  let(:context) do
    {
      current_session: session,
      ip_address: '192.168.1.1',
      user_agent: 'Mozilla/5.0'
    }
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ADMIN_DASHBOARD_URL').and_return(admin_url)
  end

  describe 'successful query' do
    context 'with complete session data' do
      let!(:parent) { create(:parent, onboarding_session: session, first_name: 'Jane', last_name: 'Doe') }
      let!(:child) { create(:child, onboarding_session: session, date_of_birth: '2012-05-15') }
      let!(:insurance) { create(:insurance, onboarding_session: session, verification_status: :pending) }

      it 'returns complete context payload' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data).to be_present
        expect(data['sessionId']).to eq(session.id)
        expect(data['onboardingPhase']).to eq('in_progress')
        expect(data['parentFirstName']).to eq('Jane')
        expect(data['childAge']).to be_a(Integer)
        expect(data['childAge']).to be >= 11
        expect(data['childAge']).to be <= 13
        expect(data['insuranceStatus']).to eq('pending')
        expect(data['hasErrors']).to be false
        expect(data['errorType']).to be_nil
        expect(data['adminLink']).to eq("#{admin_url}/sessions/#{session.id}")
      end
    end

    context 'with minimal session data' do
      it 'returns context with nil values for missing data' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data).to be_present
        expect(data['sessionId']).to eq(session.id)
        expect(data['onboardingPhase']).to eq('in_progress')
        expect(data['parentFirstName']).to be_nil
        expect(data['childAge']).to be_nil
        expect(data['insuranceStatus']).to be_nil
        expect(data['hasErrors']).to be false
        expect(data['adminLink']).to be_present
      end
    end

    it 'accepts UUID format session ID' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session.id },
        context: context
      )

      data = result.dig('data', 'generateIntercomContext')
      expect(data).to be_present
      expect(data['sessionId']).to eq(session.id)
    end

    it 'accepts sess_ prefixed session ID' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      data = result.dig('data', 'generateIntercomContext')
      expect(data).to be_present
      expect(data['sessionId']).to eq(session.id)
    end
  end

  describe 'onboarding phase' do
    it 'returns current session status' do
      session.update!(status: :insurance_pending)

      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      data = result.dig('data', 'generateIntercomContext')
      expect(data['onboardingPhase']).to eq('insurance_pending')
    end

    it 'handles all session statuses' do
      statuses = %i[started in_progress insurance_pending assessment_complete submitted]

      statuses.each do |status|
        # Create new session for each status to avoid state machine transition issues
        test_session = create(:onboarding_session, status: status)
        test_session_id = "sess_#{test_session.id.gsub('-', '')}"
        test_context = { current_session: test_session, ip_address: '192.168.1.1', user_agent: 'Mozilla/5.0' }

        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: test_session_id },
          context: test_context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data['onboardingPhase']).to eq(status.to_s)
      end
    end
  end

  describe 'parent first name' do
    context 'when parent exists' do
      let!(:parent) { create(:parent, onboarding_session: session, first_name: 'TestParent') }

      it 'returns parent first name' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data['parentFirstName']).to eq('TestParent')
      end
    end

    context 'when parent does not exist' do
      it 'returns null' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data['parentFirstName']).to be_nil
      end
    end
  end

  describe 'child age' do
    context 'when child exists' do
      let!(:child) { create(:child, onboarding_session: session, date_of_birth: 10.years.ago.to_date.to_s) }

      it 'returns calculated age' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data['childAge']).to eq(10)
      end
    end

    context 'when child does not exist' do
      it 'returns null' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data['childAge']).to be_nil
      end
    end
  end

  describe 'insurance status' do
    context 'when insurance exists' do
      let!(:insurance) { create(:insurance, onboarding_session: session, verification_status: :verified) }

      it 'returns insurance verification status' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data['insuranceStatus']).to eq('verified')
      end
    end

    context 'when insurance does not exist' do
      it 'returns null' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data['insuranceStatus']).to be_nil
      end
    end
  end

  describe 'error detection' do
    context 'with expired session' do
      before { session.update!(status: :expired) }

      it 'reports error state' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data['hasErrors']).to be true
        expect(data['errorType']).to eq('session_expired')
      end
    end

    context 'with abandoned session' do
      before { session.update!(status: :abandoned) }

      it 'reports error state' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data['hasErrors']).to be true
        expect(data['errorType']).to eq('session_abandoned')
      end
    end

    context 'with OCR extraction failed' do
      let!(:insurance) do
        create(:insurance,
          onboarding_session: session,
          verification_result: {
            'error' => {
              'code' => 'OCR_FAILED',
              'message' => 'Unable to extract text'
            }
          }
        )
      end

      it 'reports error state' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data['hasErrors']).to be true
        expect(data['errorType']).to eq('ocr_extraction_failed')
      end
    end

    context 'with eligibility verification failed' do
      let!(:insurance) { create(:insurance, onboarding_session: session, verification_status: :failed) }

      it 'reports error state' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data['hasErrors']).to be true
        expect(data['errorType']).to eq('eligibility_verification_failed')
      end
    end

    context 'with no errors' do
      let!(:parent) { create(:parent, onboarding_session: session) }
      let!(:child) { create(:child, onboarding_session: session) }
      let!(:insurance) { create(:insurance, onboarding_session: session, verification_status: :verified) }

      it 'reports no errors' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data['hasErrors']).to be false
        expect(data['errorType']).to be_nil
      end
    end
  end

  describe 'admin link' do
    it 'generates admin dashboard link' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      data = result.dig('data', 'generateIntercomContext')
      expect(data['adminLink']).to eq("#{admin_url}/sessions/#{session.id}")
    end

    context 'when ADMIN_DASHBOARD_URL is not set' do
      before do
        allow(ENV).to receive(:[]).with('ADMIN_DASHBOARD_URL').and_return(nil)
      end

      it 'uses default admin URL' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        data = result.dig('data', 'generateIntercomContext')
        expect(data['adminLink']).to start_with('https://admin.daybreak.health')
      end
    end
  end

  describe 'authorization' do
    context 'when user is not authenticated' do
      let(:context) do
        {
          current_session: nil,
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        }
      end

      it 'returns UNAUTHENTICATED error' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: session_id_prefixed },
          context: context
        )

        errors = result['errors']
        expect(errors).to be_present
        expect(errors.first['message']).to include('Access denied')
        expect(errors.first['extensions']['code']).to eq('UNAUTHENTICATED')
      end
    end

    context 'when user tries to access different session' do
      let(:other_session) { create(:onboarding_session) }
      let(:other_session_id) { "sess_#{other_session.id.gsub('-', '')}" }

      it 'returns UNAUTHENTICATED error' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: other_session_id },
          context: context
        )

        errors = result['errors']
        expect(errors).to be_present
        expect(errors.first['message']).to include('Access denied')
        expect(errors.first['extensions']['code']).to eq('UNAUTHENTICATED')
      end
    end
  end

  describe 'error handling' do
    context 'when session does not exist' do
      let(:non_existent_id) { 'sess_' + ('0' * 32) }

      it 'returns NOT_FOUND error' do
        result = DaybreakHealthBackendSchema.execute(
          query,
          variables: { sessionId: non_existent_id },
          context: context
        )

        errors = result['errors']
        expect(errors).to be_present
        expect(errors.first['message']).to include('Session not found')
        expect(errors.first['extensions']['code']).to eq('NOT_FOUND')
      end
    end
  end

  describe 'HIPAA compliance' do
    let!(:parent) do
      create(:parent,
        onboarding_session: session,
        first_name: 'Jane',
        last_name: 'Doe',
        email: 'jane.doe@example.com',
        phone: '+12025551234'  # Valid E.164 format
      )
    end

    let!(:child) do
      create(:child,
        onboarding_session: session,
        first_name: 'Child',
        last_name: 'Doe',
        date_of_birth: '2012-05-15'
      )
    end

    let!(:insurance) do
      ins = create(:insurance,
        onboarding_session: session,
        verification_status: :pending
      )
      # Update without validation since we're testing PHI sanitization, not validation
      ins.update_columns(
        payer_name: 'Blue Cross',
        member_id: 'ABC123456',
        group_number: 'GRP999'
      )
      ins
    end

    it 'only returns PHI-safe data' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      data = result.dig('data', 'generateIntercomContext')
      response_string = data.to_s

      # PHI-SAFE: session_id, first_name only, age (not DOB), status enums
      expect(data['sessionId']).to eq(session.id)
      expect(data['parentFirstName']).to eq('Jane')
      expect(data['childAge']).to be_a(Integer)
      expect(data['insuranceStatus']).to eq('pending')

      # PHI-PROHIBITED: last names
      expect(response_string).not_to include('Doe')
      expect(data.keys).not_to include('parentLastName', 'lastName', 'childLastName')

      # PHI-PROHIBITED: emails
      expect(response_string).not_to include('jane.doe@example.com')
      expect(data.keys).not_to include('email', 'parentEmail')

      # PHI-PROHIBITED: phone numbers
      expect(response_string).not_to include('5551234567')
      expect(data.keys).not_to include('phone', 'parentPhone')

      # PHI-PROHIBITED: dates of birth
      expect(response_string).not_to include('2012-05-15')
      expect(data.keys).not_to include('dob', 'dateOfBirth', 'childDob')

      # PHI-PROHIBITED: insurance details
      expect(response_string).not_to include('ABC123456')
      expect(response_string).not_to include('GRP999')
      expect(response_string).not_to include('Blue Cross')
      expect(data.keys).not_to include('memberId', 'groupNumber', 'payerName', 'policyNumber')
    end

    it 'includes only age, not DOB' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      data = result.dig('data', 'generateIntercomContext')

      expect(data['childAge']).to be_a(Integer)
      expect(data['childAge']).to be >= 11
      expect(data['childAge']).to be <= 13

      # Verify DOB is not in response
      response_string = data.to_s
      expect(response_string).not_to match(/\d{4}-\d{2}-\d{2}/)
    end

    it 'includes only status enums, not detailed info' do
      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      data = result.dig('data', 'generateIntercomContext')

      # Status enum is safe
      expect(data['insuranceStatus']).to eq('pending')
      expect(data['onboardingPhase']).to eq('in_progress')

      # Detailed info is not included
      response_string = data.to_s
      expect(response_string).not_to include('Blue Cross')
    end
  end

  describe 'integration with IntercomContextService' do
    let!(:parent) { create(:parent, onboarding_session: session, first_name: 'Jane') }
    let!(:child) { create(:child, onboarding_session: session, date_of_birth: 10.years.ago.to_date.to_s) }
    let!(:insurance) { create(:insurance, onboarding_session: session, verification_status: :verified) }

    it 'delegates to Support::IntercomContextService' do
      expected_result = {
        session_id: session.id,
        onboarding_phase: 'in_progress',
        parent_first_name: 'Jane',
        child_age: 10,
        insurance_status: 'verified',
        has_errors: false,
        error_type: nil,
        admin_link: "#{admin_url}/sessions/#{session.id}"
      }

      allow(Support::IntercomContextService).to receive(:call).with(session_id: session.id)
                                                               .and_return(expected_result)

      result = DaybreakHealthBackendSchema.execute(
        query,
        variables: { sessionId: session_id_prefixed },
        context: context
      )

      data = result.dig('data', 'generateIntercomContext')
      expect(data['sessionId']).to eq(session.id)
      expect(data['onboardingPhase']).to eq('in_progress')
      expect(data['parentFirstName']).to eq('Jane')
      expect(data['childAge']).to eq(10)
      expect(data['insuranceStatus']).to eq('verified')
      expect(data['hasErrors']).to be false
      expect(data['errorType']).to be_nil
      expect(data['adminLink']).to eq("#{admin_url}/sessions/#{session.id}")

      expect(Support::IntercomContextService).to have_received(:call).with(session_id: session.id)
    end
  end
end
