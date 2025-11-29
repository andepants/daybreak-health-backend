# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OnboardingSessionPolicy do
  subject { described_class.new(user, session) }

  let(:session) { create(:onboarding_session) }

  describe 'with anonymous user' do
    let(:user) { { role: 'anonymous' } }

    it 'allows create' do
      expect(subject.create?).to be true
    end

    it 'denies show' do
      expect(subject.show?).to be false
    end

    it 'denies update' do
      expect(subject.update?).to be false
    end

    it 'denies destroy' do
      expect(subject.destroy?).to be false
    end

    it 'denies abandon' do
      expect(subject.abandon?).to be false
    end

    it 'denies index' do
      expect(subject.index?).to be false
    end
  end

  describe 'with session owner' do
    let(:user) { { session_id: session.id, role: 'parent' } }

    it 'allows create' do
      expect(subject.create?).to be true
    end

    it 'allows show' do
      expect(subject.show?).to be true
    end

    it 'allows update' do
      expect(subject.update?).to be true
    end

    it 'denies destroy' do
      expect(subject.destroy?).to be false
    end

    it 'allows abandon' do
      expect(subject.abandon?).to be true
    end

    it 'denies index' do
      expect(subject.index?).to be false
    end
  end

  describe 'with different session owner' do
    let(:other_session) { create(:onboarding_session) }
    let(:user) { { session_id: other_session.id, role: 'parent' } }

    it 'allows create' do
      expect(subject.create?).to be true
    end

    it 'denies show' do
      expect(subject.show?).to be false
    end

    it 'denies update' do
      expect(subject.update?).to be false
    end

    it 'denies destroy' do
      expect(subject.destroy?).to be false
    end

    it 'denies abandon' do
      expect(subject.abandon?).to be false
    end
  end

  # AC 2.6.4: Role-based access control tests
  describe 'with coordinator user' do
    let(:coordinator_session) { create(:onboarding_session, role: :coordinator) }
    let(:user) { { session_id: coordinator_session.id, role: 'coordinator' } }

    it 'allows create' do
      expect(subject.create?).to be true
    end

    it 'allows show for any session' do
      expect(subject.show?).to be true
    end

    it 'denies update for other sessions' do
      expect(subject.update?).to be false
    end

    it 'allows index' do
      expect(subject.index?).to be true
    end

    it 'denies destroy' do
      expect(subject.destroy?).to be false
    end
  end

  describe 'with admin user' do
    let(:admin_session) { create(:onboarding_session, role: :admin) }
    let(:user) { { session_id: admin_session.id, role: 'admin' } }

    it 'allows show for any session' do
      expect(subject.show?).to be true
    end

    it 'allows update for any session' do
      expect(subject.update?).to be true
    end

    it 'allows index' do
      expect(subject.index?).to be true
    end

    it 'denies destroy' do
      expect(subject.destroy?).to be false
    end
  end

  describe 'with system user' do
    let(:system_session) { create(:onboarding_session, role: :system) }
    let(:user) { { session_id: system_session.id, role: 'system' } }

    it 'allows show for any session' do
      expect(subject.show?).to be true
    end

    it 'allows update for any session' do
      expect(subject.update?).to be true
    end

    it 'allows index' do
      expect(subject.index?).to be true
    end

    it 'denies destroy' do
      expect(subject.destroy?).to be false
    end
  end

  describe 'with nil user' do
    let(:user) { nil }

    it 'allows create (anonymous session creation)' do
      expect(subject.create?).to be true
    end

    it 'denies show' do
      expect(subject.show?).to be false
    end

    it 'denies update' do
      expect(subject.update?).to be false
    end

    it 'denies destroy' do
      expect(subject.destroy?).to be false
    end

    it 'denies abandon' do
      expect(subject.abandon?).to be false
    end
  end

  # AC 2.5.2: Mutation requires valid session token (cannot abandon others' sessions)
  describe 'abandon? authorization' do
    context 'when user owns the session' do
      let(:user) { { session_id: session.id, role: 'parent' } }

      it 'allows abandonment' do
        expect(subject.abandon?).to be true
      end
    end

    context 'when user does not own the session' do
      let(:other_session) { create(:onboarding_session) }
      let(:user) { { session_id: other_session.id, role: 'parent' } }

      it 'denies abandonment' do
        expect(subject.abandon?).to be false
      end
    end

    context 'when user is not authenticated' do
      let(:user) { nil }

      it 'denies abandonment' do
        expect(subject.abandon?).to be false
      end
    end

    context 'when user has no session_id claim' do
      let(:user) { { role: 'parent' } }

      it 'denies abandonment' do
        expect(subject.abandon?).to be false
      end
    end
  end

  describe 'session ownership validation' do
    it 'checks session_id claim from JWT payload' do
      user_with_session = { session_id: session.id }
      policy = described_class.new(user_with_session, session)

      expect(policy.show?).to be true
    end

    it 'handles string vs UUID comparison' do
      user_with_string_id = { session_id: session.id.to_s }
      policy = described_class.new(user_with_string_id, session)

      expect(policy.show?).to be true
    end

    it 'denies if session_id claim is missing' do
      user_without_session = { role: 'parent' }
      policy = described_class.new(user_without_session, session)

      expect(policy.show?).to be false
    end
  end

  describe OnboardingSessionPolicy::Scope do
    subject { described_class.new(user, OnboardingSession) }

    let!(:session1) { create(:onboarding_session, role: :anonymous) }
    let!(:session2) { create(:onboarding_session, role: :parent) }

    describe 'with session owner' do
      let(:user) { { session_id: session.id, role: 'parent' } }

      it 'returns only owned session' do
        other_session = create(:onboarding_session)

        result = subject.resolve
        expect(result).to include(session)
        expect(result).not_to include(other_session)
      end

      it 'returns empty if user has no session_id' do
        user_without_session = { role: 'parent' }
        scope = described_class.new(user_without_session, OnboardingSession)

        result = scope.resolve
        expect(result).to be_empty
      end
    end

    # AC 2.6.4: Role-based scoping tests
    describe 'with coordinator user' do
      let(:coordinator_session) { create(:onboarding_session, role: :coordinator) }
      let(:user) { { session_id: coordinator_session.id, role: 'coordinator' } }

      it 'returns all sessions' do
        result = subject.resolve
        expect(result).to include(session1, session2, coordinator_session)
      end
    end

    describe 'with admin user' do
      let(:admin_session) { create(:onboarding_session, role: :admin) }
      let(:user) { { session_id: admin_session.id, role: 'admin' } }

      it 'returns all sessions' do
        result = subject.resolve
        expect(result).to include(session1, session2, admin_session)
      end
    end

    describe 'with system user' do
      let(:system_session) { create(:onboarding_session, role: :system) }
      let(:user) { { session_id: system_session.id, role: 'system' } }

      it 'returns all sessions' do
        result = subject.resolve
        expect(result).to include(session1, session2, system_session)
      end
    end

    describe 'with nil user' do
      let(:user) { nil }

      it 'returns empty scope' do
        result = subject.resolve
        expect(result).to be_empty
      end
    end
  end

  describe 'security guarantees' do
    it 'never allows destroying sessions' do
      # Test with all possible user types
      users = [
        nil,
        { role: 'anonymous' },
        { session_id: session.id, role: 'parent' },
        { session_id: 'other-id', role: 'parent' },
        { role: 'admin' }
      ]

      users.each do |test_user|
        policy = described_class.new(test_user, session)
        expect(policy.destroy?).to be(false),
                                   "Expected destroy? to be false for user: #{test_user.inspect}"
      end
    end

    it 'never allows listing all sessions' do
      users = [
        nil,
        { role: 'anonymous' },
        { session_id: session.id, role: 'parent' }
      ]

      users.each do |test_user|
        policy = described_class.new(test_user, session)
        expect(policy.index?).to be(false),
                                 "Expected index? to be false for user: #{test_user.inspect}"
      end
    end

    it 'always allows creating new sessions (anonymous onboarding)' do
      users = [
        nil,
        { role: 'anonymous' },
        { session_id: session.id, role: 'parent' },
        { session_id: 'other-id', role: 'parent' }
      ]

      users.each do |test_user|
        policy = described_class.new(test_user, session)
        expect(policy.create?).to be(true),
                                   "Expected create? to be true for user: #{test_user.inspect}"
      end
    end
  end
end
