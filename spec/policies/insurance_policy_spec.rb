# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InsurancePolicy, type: :policy do
  subject(:policy) { described_class.new(user, insurance) }

  let(:session) { create(:onboarding_session) }
  let(:insurance) { create(:insurance, onboarding_session: session) }

  describe 'anonymous user' do
    let(:user) { { role: 'anonymous', session_id: session.id } }

    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to forbid_action(:destroy) }
  end

  describe 'parent user (owns session)' do
    let(:user) { { role: 'parent', session_id: session.id } }

    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to forbid_action(:destroy) }
  end

  describe 'parent user (does not own session)' do
    let(:other_session) { create(:onboarding_session) }
    let(:user) { { role: 'parent', session_id: other_session.id } }

    it { is_expected.to forbid_action(:create) }
    it { is_expected.to forbid_action(:show) }
    it { is_expected.to forbid_action(:update) }
    it { is_expected.to forbid_action(:destroy) }
  end

  describe 'coordinator user' do
    let(:user) { { role: 'coordinator', session_id: nil } }

    it { is_expected.to forbid_action(:create) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to forbid_action(:update) }
    it { is_expected.to forbid_action(:destroy) }
    it { is_expected.to permit_action(:index) }
  end

  describe 'admin user' do
    let(:user) { { role: 'admin', session_id: nil } }

    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to forbid_action(:destroy) }
    it { is_expected.to permit_action(:index) }
  end

  describe 'system user' do
    let(:user) { { role: 'system', session_id: nil } }

    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to forbid_action(:destroy) }
    it { is_expected.to permit_action(:index) }
  end
end
