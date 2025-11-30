# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentPlan, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:onboarding_session) }
  end

  describe 'validations' do
    subject { build(:payment_plan) }

    it { is_expected.to validate_presence_of(:plan_duration_months) }
    it { is_expected.to validate_presence_of(:monthly_amount) }
    it { is_expected.to validate_presence_of(:total_amount) }
    it { is_expected.to validate_presence_of(:payment_method_preference) }
    it { is_expected.to validate_presence_of(:status) }

    it { is_expected.to validate_numericality_of(:plan_duration_months).is_greater_than_or_equal_to(0).only_integer }
    it { is_expected.to validate_numericality_of(:monthly_amount).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:total_amount).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:discount_applied).is_greater_than_or_equal_to(0).allow_nil }

    it 'is valid with valid attributes' do
      payment_plan = build(:payment_plan)
      expect(payment_plan).to be_valid
    end

    it 'is invalid with negative plan duration' do
      payment_plan = build(:payment_plan, plan_duration_months: -1)
      expect(payment_plan).not_to be_valid
    end

    it 'is invalid with zero monthly amount' do
      payment_plan = build(:payment_plan, monthly_amount: 0)
      expect(payment_plan).not_to be_valid
    end

    it 'is invalid with negative monthly amount' do
      payment_plan = build(:payment_plan, monthly_amount: -100)
      expect(payment_plan).not_to be_valid
    end

    it 'is invalid with zero total amount' do
      payment_plan = build(:payment_plan, total_amount: 0)
      expect(payment_plan).not_to be_valid
    end

    it 'is invalid with negative total amount' do
      payment_plan = build(:payment_plan, total_amount: -500)
      expect(payment_plan).not_to be_valid
    end

    it 'is invalid with negative discount' do
      payment_plan = build(:payment_plan, discount_applied: -50)
      expect(payment_plan).not_to be_valid
    end

    it 'is valid with zero discount' do
      payment_plan = build(:payment_plan, discount_applied: 0)
      expect(payment_plan).to be_valid
    end
  end

  describe 'enums' do
    it 'defines status enum' do
      expect(described_class.statuses).to eq({
        'pending' => 0,
        'active' => 1,
        'completed' => 2,
        'cancelled' => 3
      })
    end

    it 'defines payment_method_preference enum' do
      expect(described_class.payment_method_preferences).to eq({
        'card' => 0,
        'hsa_fsa' => 1,
        'bank_transfer' => 2
      })
    end
  end

  describe 'scopes' do
    let!(:active_plan) { create(:payment_plan, :active) }
    let!(:pending_plan) { create(:payment_plan, :pending) }
    let!(:completed_plan) { create(:payment_plan, :completed) }
    let!(:cancelled_plan) { create(:payment_plan, :cancelled) }

    describe '.active_plans' do
      it 'returns only active plans' do
        expect(described_class.active_plans).to contain_exactly(active_plan)
      end
    end

    describe '.pending_plans' do
      it 'returns only pending plans' do
        expect(described_class.pending_plans).to contain_exactly(pending_plan)
      end
    end

    describe '.for_session' do
      let(:session) { create(:onboarding_session) }
      let!(:session_plan) { create(:payment_plan, onboarding_session: session) }
      let!(:other_plan) { create(:payment_plan) }

      it 'returns plans for specific session' do
        expect(described_class.for_session(session.id)).to contain_exactly(session_plan)
      end
    end
  end

  describe '#upfront_payment?' do
    it 'returns true for upfront payment (duration 0)' do
      plan = build(:payment_plan, :upfront)
      expect(plan.upfront_payment?).to be true
    end

    it 'returns false for monthly payment plans' do
      plan = build(:payment_plan, :six_month)
      expect(plan.upfront_payment?).to be false
    end
  end

  describe '#monthly_payment?' do
    it 'returns false for upfront payment' do
      plan = build(:payment_plan, :upfront)
      expect(plan.monthly_payment?).to be false
    end

    it 'returns true for monthly payment plans' do
      plan = build(:payment_plan, :six_month)
      expect(plan.monthly_payment?).to be true
    end
  end

  describe '#description' do
    context 'for upfront payment' do
      it 'returns description with discount' do
        plan = build(:payment_plan, :upfront)
        expect(plan.description).to include('Pay in full')
        expect(plan.description).to include('discount')
      end

      it 'returns description without discount when no discount applied' do
        plan = build(:payment_plan, plan_duration_months: 0, monthly_amount: 1000, total_amount: 1000, discount_applied: 0)
        expect(plan.description).to eq('Pay in full')
      end
    end

    context 'for monthly payment plans' do
      it 'returns description with duration and monthly amount' do
        plan = build(:payment_plan, :six_month)
        expect(plan.description).to include('6 monthly payments')
        expect(plan.description).to include('$200.0')
      end

      it 'returns description for 3-month plan' do
        plan = build(:payment_plan, :three_month)
        expect(plan.description).to include('3 monthly payments')
      end

      it 'returns description for 12-month plan' do
        plan = build(:payment_plan, :twelve_month)
        expect(plan.description).to include('12 monthly payments')
      end
    end
  end

  describe '#discount_percentage' do
    it 'calculates discount percentage correctly' do
      # Total: 950, Discount: 50, Original: 1000
      # Percentage: 50/1000 * 100 = 5%
      plan = build(:payment_plan, :upfront)
      expect(plan.discount_percentage).to eq(5.0)
    end

    it 'returns nil when no discount applied' do
      plan = build(:payment_plan, discount_applied: 0)
      expect(plan.discount_percentage).to be_nil
    end

    it 'handles 10% discount' do
      # Total: 900, Discount: 100, Original: 1000
      plan = build(:payment_plan, total_amount: 900, discount_applied: 100)
      expect(plan.discount_percentage).to eq(10.0)
    end

    it 'returns nil when total is zero' do
      plan = build(:payment_plan, total_amount: 0, discount_applied: 0)
      expect(plan.discount_percentage).to be_nil
    end
  end

  describe 'payment method preferences' do
    it 'can be created with card payment method' do
      plan = create(:payment_plan, payment_method_preference: :card)
      expect(plan.card?).to be true
    end

    it 'can be created with HSA/FSA payment method' do
      plan = create(:payment_plan, :hsa_fsa)
      expect(plan.hsa_fsa?).to be true
    end

    it 'can be created with bank transfer payment method' do
      plan = create(:payment_plan, :bank_transfer)
      expect(plan.bank_transfer?).to be true
    end
  end

  describe 'status transitions' do
    it 'defaults to pending status' do
      plan = create(:payment_plan)
      expect(plan.pending?).to be true
    end

    it 'can transition to active' do
      plan = create(:payment_plan, :pending)
      plan.active!
      expect(plan.active?).to be true
    end

    it 'can transition to completed' do
      plan = create(:payment_plan, :active)
      plan.completed!
      expect(plan.completed?).to be true
    end

    it 'can transition to cancelled' do
      plan = create(:payment_plan, :active)
      plan.cancelled!
      expect(plan.cancelled?).to be true
    end
  end
end
