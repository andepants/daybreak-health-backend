# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupportRequest, type: :model do
  describe 'associations' do
    it { should belong_to(:onboarding_session) }
  end

  describe 'validations' do
    it { should validate_presence_of(:source) }
    it { should validate_presence_of(:onboarding_session_id) }
  end

  describe 'scopes' do
    let(:session) { create(:onboarding_session) }

    before do
      create(:support_request, :resolved, onboarding_session: session)
      create(:support_request, onboarding_session: session)
      create(:support_request, :from_welcome_screen, onboarding_session: session)
    end

    describe '.resolved' do
      it 'returns only resolved support requests' do
        expect(SupportRequest.resolved.count).to eq(1)
        expect(SupportRequest.resolved.first.resolved).to be true
      end
    end

    describe '.unresolved' do
      it 'returns only unresolved support requests' do
        expect(SupportRequest.unresolved.count).to eq(2)
        expect(SupportRequest.unresolved.all? { |sr| !sr.resolved }).to be true
      end
    end

    describe '.by_source' do
      it 'filters support requests by source' do
        requests = SupportRequest.by_source('welcome-screen')
        expect(requests.count).to eq(1)
        expect(requests.first.source).to eq('welcome-screen')
      end
    end

    describe '.recent' do
      it 'orders support requests by created_at descending' do
        requests = SupportRequest.recent
        expect(requests.first.created_at).to be >= requests.last.created_at
      end
    end
  end

  describe '#standard_source?' do
    it 'returns true for standard source values' do
      request = build(:support_request, source: 'welcome-screen')
      expect(request.standard_source?).to be true
    end

    it 'returns false for non-standard source values' do
      request = build(:support_request, source: 'custom-location')
      expect(request.standard_source?).to be false
    end
  end

  describe '#mark_resolved!' do
    it 'marks the support request as resolved' do
      request = create(:support_request)
      expect(request.resolved).to be false

      request.mark_resolved!

      expect(request.reload.resolved).to be true
    end
  end

  describe '#mark_unresolved!' do
    it 'marks the support request as unresolved' do
      request = create(:support_request, :resolved)
      expect(request.resolved).to be true

      request.mark_unresolved!

      expect(request.reload.resolved).to be false
    end
  end

  describe 'database defaults' do
    it 'sets resolved to false by default' do
      session = create(:onboarding_session)
      request = SupportRequest.create!(
        onboarding_session: session,
        source: 'test-source'
      )

      expect(request.resolved).to be false
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      request = create(:support_request)
      expect(request).to be_valid
    end

    it 'has valid traits' do
      expect(create(:support_request, :resolved)).to be_valid
      expect(create(:support_request, :from_welcome_screen)).to be_valid
      expect(create(:support_request, :from_ai_intake)).to be_valid
      expect(create(:support_request, :from_assessment)).to be_valid
      expect(create(:support_request, :from_error_state)).to be_valid
    end
  end
end
