# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Errors::ErrorCodes do
  describe 'error code constants' do
    it 'defines UNAUTHENTICATED' do
      expect(described_class::UNAUTHENTICATED).to eq('UNAUTHENTICATED')
    end

    it 'defines FORBIDDEN' do
      expect(described_class::FORBIDDEN).to eq('FORBIDDEN')
    end

    it 'defines NOT_FOUND' do
      expect(described_class::NOT_FOUND).to eq('NOT_FOUND')
    end

    it 'defines VALIDATION_ERROR' do
      expect(described_class::VALIDATION_ERROR).to eq('VALIDATION_ERROR')
    end

    it 'defines SESSION_EXPIRED' do
      expect(described_class::SESSION_EXPIRED).to eq('SESSION_EXPIRED')
    end

    it 'defines RATE_LIMITED' do
      expect(described_class::RATE_LIMITED).to eq('RATE_LIMITED')
    end

    it 'defines INTERNAL_ERROR' do
      expect(described_class::INTERNAL_ERROR).to eq('INTERNAL_ERROR')
    end

    it 'defines CONFLICT' do
      expect(described_class::CONFLICT).to eq('CONFLICT')
    end

    it 'defines SERVICE_UNAVAILABLE' do
      expect(described_class::SERVICE_UNAVAILABLE).to eq('SERVICE_UNAVAILABLE')
    end
  end

  describe 'ALL_CODES' do
    it 'includes all defined error codes' do
      expect(described_class::ALL_CODES).to include(
        'UNAUTHENTICATED',
        'FORBIDDEN',
        'NOT_FOUND',
        'VALIDATION_ERROR',
        'SESSION_EXPIRED',
        'RATE_LIMITED',
        'INTERNAL_ERROR',
        'CONFLICT',
        'SERVICE_UNAVAILABLE'
      )
    end

    it 'is frozen' do
      expect(described_class::ALL_CODES).to be_frozen
    end

    it 'has at least 9 error codes' do
      expect(described_class::ALL_CODES.length).to be >= 9
    end
  end

  describe '.valid?' do
    it 'returns true for valid error codes' do
      expect(described_class.valid?('UNAUTHENTICATED')).to be true
      expect(described_class.valid?('FORBIDDEN')).to be true
      expect(described_class.valid?('NOT_FOUND')).to be true
      expect(described_class.valid?('VALIDATION_ERROR')).to be true
    end

    it 'returns false for invalid error codes' do
      expect(described_class.valid?('INVALID_CODE')).to be false
      expect(described_class.valid?('unauthenticated')).to be false
      expect(described_class.valid?('')).to be false
      expect(described_class.valid?(nil)).to be false
    end
  end

  describe 'alignment with Architecture document' do
    it 'matches the required error codes from Architecture doc' do
      required_codes = %w[
        UNAUTHENTICATED
        FORBIDDEN
        NOT_FOUND
        VALIDATION_ERROR
        INTERNAL_ERROR
      ]

      required_codes.each do |code|
        expect(described_class::ALL_CODES).to include(code),
                                              "Expected ALL_CODES to include #{code} as specified in Architecture doc"
      end
    end
  end
end
