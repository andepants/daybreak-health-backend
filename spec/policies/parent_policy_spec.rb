# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ParentPolicy, type: :policy do
  subject(:policy) { described_class.new(user, parent) }

  let(:session) { create(:onboarding_session) }
  let(:parent) { create(:parent, onboarding_session: session) }

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
    let!(:own_parent) { create(:parent, onboarding_session: session) }
    let!(:other_parent) { create(:parent, onboarding_session: other_session) }

    describe 'for anonymous user' do
      let(:user) { { role: 'anonymous', session_id: session.id } }

      it 'returns only own parent' do
        scope = described_class::Scope.new(user, Parent).resolve
        expect(scope).to include(own_parent)
        expect(scope).not_to include(other_parent)
      end
    end

    describe 'for coordinator' do
      let(:user) { { role: 'coordinator', session_id: nil } }

      it 'returns all parents' do
        scope = described_class::Scope.new(user, Parent).resolve
        expect(scope).to include(own_parent, other_parent)
      end
    end

    describe 'for admin' do
      let(:user) { { role: 'admin', session_id: nil } }

      it 'returns all parents' do
        scope = described_class::Scope.new(user, Parent).resolve
        expect(scope).to include(own_parent, other_parent)
      end
    end
  end
end
