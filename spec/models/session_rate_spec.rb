# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionRate, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:service_type) }
    it { should validate_presence_of(:base_rate) }
    it { should validate_presence_of(:effective_date) }

    it 'validates base_rate is positive' do
      rate = build(:session_rate, base_rate: -10.0)
      expect(rate).not_to be_valid
      expect(rate.errors[:base_rate]).to include('must be greater than 0')
    end

    it 'validates end_date is after effective_date' do
      rate = build(:session_rate, effective_date: Date.current, end_date: 1.day.ago)
      expect(rate).not_to be_valid
      expect(rate.errors[:end_date]).to include('must be after effective_date')
    end

    it 'allows nil end_date' do
      rate = build(:session_rate, end_date: nil)
      expect(rate).to be_valid
    end
  end

  describe 'enums' do
    it 'defines service_type enum' do
      expect(SessionRate.service_types.keys).to include(
        'intake',
        'individual_therapy',
        'family_therapy',
        'onsite_care'
      )
    end
  end

  describe 'scopes' do
    let!(:active_rate) { create(:session_rate, effective_date: 1.month.ago, end_date: nil) }
    let!(:expired_rate) { create(:session_rate, :expired) }
    let!(:future_rate) { create(:session_rate, :future) }

    describe '.active' do
      it 'returns rates with no end_date or future end_date' do
        expect(SessionRate.active).to include(active_rate, future_rate)
        expect(SessionRate.active).not_to include(expired_rate)
      end
    end

    describe '.effective_on' do
      it 'returns rates effective on given date' do
        expect(SessionRate.effective_on(Date.current)).to include(active_rate)
        expect(SessionRate.effective_on(Date.current)).not_to include(expired_rate, future_rate)
      end
    end

    describe '.for_service_type' do
      let!(:family_rate) { create(:session_rate, :family_therapy) }

      it 'returns rates for specific service type' do
        expect(SessionRate.for_service_type('family_therapy')).to include(family_rate)
        expect(SessionRate.for_service_type('family_therapy')).not_to include(active_rate)
      end
    end
  end

  describe '.current_rate_for' do
    let!(:current_rate) { create(:session_rate, service_type: 'individual_therapy', effective_date: 1.month.ago) }
    let!(:old_rate) { create(:session_rate, service_type: 'individual_therapy', effective_date: 1.year.ago, end_date: 2.months.ago) }

    it 'returns current active rate for service type' do
      rate = SessionRate.current_rate_for(service_type: 'individual_therapy')
      expect(rate).to eq(current_rate)
    end

    it 'returns nil if no rate found' do
      rate = SessionRate.current_rate_for(service_type: 'onsite_care')
      expect(rate).to be_nil
    end

    it 'accepts date parameter for historical lookups' do
      rate = SessionRate.current_rate_for(service_type: 'individual_therapy', date: 6.months.ago)
      expect(rate).to eq(old_rate)
    end
  end

  describe '.base_rate_for' do
    let!(:rate) { create(:session_rate, service_type: 'family_therapy', base_rate: 200.00) }

    it 'returns base rate amount for service type' do
      amount = SessionRate.base_rate_for(service_type: 'family_therapy')
      expect(amount).to eq(200.00)
    end

    it 'returns nil if no rate found' do
      amount = SessionRate.base_rate_for(service_type: 'intake')
      expect(amount).to be_nil
    end
  end

  describe 'auditing' do
    it 'includes Auditable concern' do
      expect(SessionRate.ancestors).to include(Auditable)
    end
  end
end
