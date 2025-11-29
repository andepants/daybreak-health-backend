# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChildPolicy, type: :policy do
  subject(:policy) { described_class.new(user, child) }

  let(:session) { create(:onboarding_session) }
  let(:child) { create(:child, onboarding_session: session) }

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

  describe 'Scope' do
    let(:other_session) { create(:onboarding_session) }
    let!(:own_child) { create(:child, onboarding_session: session) }
    let!(:other_child) { create(:child, onboarding_session: other_session) }

    describe 'for anonymous user' do
      let(:user) { { role: 'anonymous', session_id: session.id } }

      it 'returns only own child' do
        scope = described_class::Scope.new(user, Child).resolve
        expect(scope).to include(own_child)
        expect(scope).not_to include(other_child)
      end
    end

    describe 'for coordinator' do
      let(:user) { { role: 'coordinator', session_id: nil } }

      it 'returns all children' do
        scope = described_class::Scope.new(user, Child).resolve
        expect(scope).to include(own_child, other_child)
      end
    end

    describe 'for admin' do
      let(:user) { { role: 'admin', session_id: nil } }

      it 'returns all children' do
        scope = described_class::Scope.new(user, Child).resolve
        expect(scope).to include(own_child, other_child)
      end
    end
  end
end
