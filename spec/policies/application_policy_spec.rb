# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationPolicy do
  subject { described_class.new(user, record) }

  let(:user) { { id: 'user-123', role: 'parent' } }
  let(:record) { double('Record', id: 'record-123') }

  describe 'default deny behavior' do
    it 'denies index? by default' do
      expect(subject.index?).to be false
    end

    it 'denies show? by default' do
      expect(subject.show?).to be false
    end

    it 'denies create? by default' do
      expect(subject.create?).to be false
    end

    it 'denies update? by default' do
      expect(subject.update?).to be false
    end

    it 'denies destroy? by default' do
      expect(subject.destroy?).to be false
    end

    it 'denies new? by default' do
      expect(subject.new?).to be false
    end

    it 'denies edit? by default' do
      expect(subject.edit?).to be false
    end
  end

  describe '#initialize' do
    it 'stores user' do
      expect(subject.user).to eq(user)
    end

    it 'stores record' do
      expect(subject.record).to eq(record)
    end
  end

  describe 'aliased methods' do
    it 'new? delegates to create?' do
      allow(subject).to receive(:create?).and_return(true)
      expect(subject.new?).to eq(subject.create?)
    end

    it 'edit? delegates to update?' do
      allow(subject).to receive(:update?).and_return(true)
      expect(subject.edit?).to eq(subject.update?)
    end
  end

  describe ApplicationPolicy::Scope do
    subject { described_class.new(user, scope) }

    let(:scope) { double('Scope') }

    describe '#initialize' do
      it 'stores user' do
        expect(subject.send(:user)).to eq(user)
      end

      it 'stores scope' do
        expect(subject.send(:scope)).to eq(scope)
      end
    end

    describe '#resolve' do
      it 'raises NotImplementedError' do
        expect {
          subject.resolve
        }.to raise_error(NoMethodError, /You must define #resolve/)
      end
    end
  end

  describe 'security principle' do
    it 'all policy methods return false by default (fail-safe)' do
      policy_methods = %i[index? show? create? update? destroy?]

      policy_methods.each do |method|
        expect(subject.public_send(method)).to be(false),
                                               "Expected #{method} to return false (default deny)"
      end
    end

    it 'handles nil user gracefully' do
      policy = described_class.new(nil, record)

      expect(policy.show?).to be false
      expect(policy.create?).to be false
      expect(policy.update?).to be false
    end

    it 'handles nil record gracefully' do
      policy = described_class.new(user, nil)

      expect(policy.show?).to be false
      expect(policy.create?).to be false
      expect(policy.update?).to be false
    end
  end
end
