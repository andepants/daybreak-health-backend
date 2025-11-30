# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SelfPayRate, type: :model do
  describe 'validations' do
    subject { build(:self_pay_rate) }

    it { is_expected.to validate_presence_of(:session_type) }
    it { is_expected.to validate_presence_of(:base_rate) }
    it { is_expected.to validate_presence_of(:effective_date) }
    it { is_expected.to validate_numericality_of(:base_rate).is_greater_than(0) }

    context 'end_date validation' do
      it 'allows nil end_date' do
        rate = build(:self_pay_rate, end_date: nil)
        expect(rate).to be_valid
      end

      it 'allows end_date after effective_date' do
        rate = build(:self_pay_rate, effective_date: Date.current, end_date: Date.current + 1.year)
        expect(rate).to be_valid
      end

      it 'does not allow end_date before effective_date' do
        rate = build(:self_pay_rate, effective_date: Date.current, end_date: Date.current - 1.day)
        expect(rate).not_to be_valid
        expect(rate.errors[:end_date]).to include('must be after effective_date')
      end
    end
  end

  describe 'scopes' do
    let!(:current_rate) { create(:self_pay_rate, effective_date: 1.month.ago, end_date: nil) }
    let!(:expired_rate) { create(:self_pay_rate, :expired) }
    let!(:future_rate) { create(:self_pay_rate, :future) }

    describe '.currently_active' do
      it 'returns only currently active rates' do
        results = described_class.currently_active
        expect(results).to include(current_rate)
        expect(results).not_to include(expired_rate)
        expect(results).not_to include(future_rate)
      end
    end

    describe '.effective_on' do
      it 'returns rates effective on a given date' do
        results = described_class.effective_on(Date.current)
        expect(results).to include(current_rate)
        expect(results).not_to include(expired_rate)
        expect(results).not_to include(future_rate)
      end

      it 'returns expired rates when querying past dates' do
        results = described_class.effective_on(1.year.ago)
        expect(results).to include(expired_rate)
        expect(results).not_to include(current_rate)
      end
    end

    describe '.for_session_type' do
      let!(:family_rate) { create(:self_pay_rate, :family_therapy) }

      it 'filters by session type' do
        results = described_class.for_session_type('family_therapy')
        expect(results).to include(family_rate)
        expect(results).not_to include(current_rate)
      end
    end
  end

  describe '.get_rate_for' do
    before do
      # Clean up any seeded data to ensure clean test environment
      described_class.destroy_all
    end

    let!(:current_rate) { create(:self_pay_rate, effective_date: 1.month.ago, end_date: nil) }
    let!(:expired_rate) { create(:self_pay_rate, :expired) }

    it 'returns the current active rate for a session type' do
      result = described_class.get_rate_for('individual_therapy')
      expect(result).to eq(current_rate)
    end

    it 'returns nil if no active rate exists' do
      result = described_class.get_rate_for('family_therapy')
      expect(result).to be_nil
    end

    it 'can query historical rates by date' do
      result = described_class.get_rate_for('individual_therapy', 1.year.ago)
      expect(result).to eq(expired_rate)
    end

    it 'returns most recent rate when multiple rates exist' do
      older_rate = create(:self_pay_rate, effective_date: 2.months.ago, end_date: nil)
      newer_rate = create(:self_pay_rate, effective_date: 1.week.ago, end_date: nil)

      result = described_class.get_rate_for('individual_therapy')
      expect(result).to eq(newer_rate)
    end
  end

  describe '#sliding_scale_tiers' do
    context 'when sliding scale is available' do
      let(:rate) { create(:self_pay_rate, sliding_scale_available: true) }

      it 'returns the sliding scale tiers from metadata' do
        tiers = rate.sliding_scale_tiers
        expect(tiers).to be_an(Array)
        expect(tiers.first['income_range']).to eq('0-25000')
        expect(tiers.first['discount_percent']).to eq(50)
      end
    end

    context 'when sliding scale is not available' do
      let(:rate) { create(:self_pay_rate, :without_sliding_scale) }

      it 'returns empty array' do
        expect(rate.sliding_scale_tiers).to eq([])
      end
    end
  end

  describe '#package_options' do
    context 'when package pricing is available' do
      let(:rate) { create(:self_pay_rate, package_pricing_available: true) }

      it 'returns the package options from metadata' do
        packages = rate.package_options
        expect(packages).to be_an(Array)
        expect(packages.first['sessions']).to eq(4)
        expect(packages.first['total_price']).to eq(280)
      end
    end

    context 'when package pricing is not available' do
      let(:rate) { create(:self_pay_rate, :without_packages) }

      it 'returns empty array' do
        expect(rate.package_options).to eq([])
      end
    end
  end
end
