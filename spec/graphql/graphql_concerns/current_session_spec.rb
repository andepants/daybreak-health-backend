# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GraphqlConcerns::CurrentSession do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include GraphqlConcerns::CurrentSession

      attr_accessor :context

      def initialize(context)
        @context = context
      end
    end
  end

  let(:session) { create(:onboarding_session) }
  let(:user) { { session_id: session.id, role: 'parent', user_id: 'user-123' } }
  let(:context) { { current_session: session, current_user: user } }
  let(:instance) { test_class.new(context) }

  describe '#current_session' do
    it 'extracts session from context' do
      expect(instance.current_session).to eq(session)
    end

    it 'returns nil when session is not in context' do
      instance.context = {}
      expect(instance.current_session).to be_nil
    end

    it 'handles nil context gracefully' do
      instance.context = nil
      expect { instance.current_session }.not_to raise_error
    end
  end

  describe '#current_user' do
    it 'extracts user from context' do
      expect(instance.current_user).to eq(user)
    end

    it 'returns nil when user is not in context' do
      instance.context = {}
      expect(instance.current_user).to be_nil
    end
  end

  describe '#authenticated?' do
    it 'returns true when user is present' do
      expect(instance.authenticated?).to be true
    end

    it 'returns false when user is nil' do
      instance.context = { current_user: nil }
      expect(instance.authenticated?).to be false
    end

    it 'returns false when user is not in context' do
      instance.context = {}
      expect(instance.authenticated?).to be false
    end
  end

  describe '#session_exists?' do
    it 'returns true when session is present' do
      expect(instance.session_exists?).to be true
    end

    it 'returns false when session is nil' do
      instance.context = { current_session: nil }
      expect(instance.session_exists?).to be false
    end

    it 'returns false when session is not in context' do
      instance.context = {}
      expect(instance.session_exists?).to be false
    end
  end

  describe '#require_authentication!' do
    it 'does not raise error when authenticated' do
      expect { instance.require_authentication! }.not_to raise_error
    end

    it 'raises GraphQL::ExecutionError when not authenticated' do
      instance.context = {}

      expect {
        instance.require_authentication!
      }.to raise_error(GraphQL::ExecutionError, 'Authentication required')
    end

    it 'includes UNAUTHENTICATED code in error extensions' do
      instance.context = {}

      begin
        instance.require_authentication!
      rescue GraphQL::ExecutionError => e
        expect(e.extensions[:code]).to eq('UNAUTHENTICATED')
      end
    end

    it 'includes timestamp in error extensions' do
      instance.context = {}

      begin
        instance.require_authentication!
      rescue GraphQL::ExecutionError => e
        expect(e.extensions[:timestamp]).to be_present
      end
    end
  end

  describe '#require_session!' do
    it 'does not raise error when session exists' do
      expect { instance.require_session! }.not_to raise_error
    end

    it 'raises GraphQL::ExecutionError when session is missing' do
      instance.context = {}

      expect {
        instance.require_session!
      }.to raise_error(GraphQL::ExecutionError, 'Session required')
    end

    it 'includes UNAUTHENTICATED code in error extensions' do
      instance.context = {}

      begin
        instance.require_session!
      rescue GraphQL::ExecutionError => e
        expect(e.extensions[:code]).to eq('UNAUTHENTICATED')
      end
    end
  end

  describe '#current_session_id' do
    it 'returns session ID when session exists' do
      expect(instance.current_session_id).to eq(session.id)
    end

    it 'returns nil when session is missing' do
      instance.context = {}
      expect(instance.current_session_id).to be_nil
    end
  end

  describe '#current_user_id' do
    it 'returns user ID from user hash' do
      expect(instance.current_user_id).to eq('user-123')
    end

    it 'returns nil when user is missing' do
      instance.context = {}
      expect(instance.current_user_id).to be_nil
    end

    it 'returns nil when user_id is not in user hash' do
      instance.context = { current_user: { role: 'parent' } }
      expect(instance.current_user_id).to be_nil
    end
  end

  describe '#current_user_role' do
    it 'returns role from user hash' do
      expect(instance.current_user_role).to eq('parent')
    end

    it 'returns nil when user is missing' do
      instance.context = {}
      expect(instance.current_user_role).to be_nil
    end

    it 'returns nil when role is not in user hash' do
      instance.context = { current_user: { user_id: '123' } }
      expect(instance.current_user_role).to be_nil
    end
  end

  describe '#has_role?' do
    it 'returns true when user has the specified role' do
      expect(instance.has_role?('parent')).to be true
    end

    it 'returns false when user has a different role' do
      expect(instance.has_role?('admin')).to be false
    end

    it 'handles symbol argument' do
      expect(instance.has_role?(:parent)).to be true
    end

    it 'handles string argument' do
      expect(instance.has_role?('parent')).to be true
    end

    it 'returns false when user is missing' do
      instance.context = {}
      expect(instance.has_role?('parent')).to be false
    end
  end

  describe '#anonymous?' do
    it 'returns true when role is anonymous' do
      instance.context = { current_user: { role: 'anonymous' } }
      expect(instance.anonymous?).to be true
    end

    it 'returns false when role is not anonymous' do
      expect(instance.anonymous?).to be false
    end
  end

  describe '#admin?' do
    it 'returns true when role is admin' do
      instance.context = { current_user: { role: 'admin' } }
      expect(instance.admin?).to be true
    end

    it 'returns false when role is not admin' do
      expect(instance.admin?).to be false
    end
  end

  describe '#parent?' do
    it 'returns true when role is parent' do
      expect(instance.parent?).to be true
    end

    it 'returns false when role is not parent' do
      instance.context = { current_user: { role: 'admin' } }
      expect(instance.parent?).to be false
    end
  end

  describe 'integration with GraphQL mutations' do
    it 'can be included in BaseMutation' do
      expect(Mutations::BaseMutation.ancestors).to include(described_class)
    end
  end
end
