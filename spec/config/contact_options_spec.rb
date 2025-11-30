# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactOptions do
  describe '.for_parent' do
    context 'with valid configuration' do
      before do
        ENV['SUPPORT_PHONE'] = '1-800-DAYBREAK'
        ENV['SUPPORT_EMAIL'] = 'support@daybreakhealth.com'
        ENV['CHAT_HOURS'] = 'Monday-Friday 9am-5pm PT'
      end

      after do
        ENV.delete('SUPPORT_PHONE')
        ENV.delete('SUPPORT_EMAIL')
        ENV.delete('CHAT_HOURS')
        ENV.delete('CHAT_HOURS_TIMEZONE')
      end

      it 'returns contact options hash' do
        result = described_class.for_parent
        expect(result).to be_a(Hash)
      end

      it 'includes phone number' do
        result = described_class.for_parent
        expect(result[:phone]).to eq('1-800-DAYBREAK')
      end

      it 'includes email address' do
        result = described_class.for_parent
        expect(result[:email]).to eq('support@daybreakhealth.com')
      end

      it 'includes chat hours' do
        result = described_class.for_parent
        expect(result[:chat_hours]).to include('Monday-Friday 9am-5pm')
      end
    end

    context 'with missing configuration' do
      before do
        ENV.delete('SUPPORT_PHONE')
        ENV.delete('SUPPORT_EMAIL')
        ENV.delete('CHAT_HOURS')
      end

      it 'raises error when SUPPORT_PHONE is missing' do
        ENV['SUPPORT_EMAIL'] = 'support@example.com'
        ENV['CHAT_HOURS'] = '9am-5pm'

        expect do
          described_class.for_parent
        end.to raise_error(ContactOptions::ConfigurationError, /SUPPORT_PHONE.*required/)
      end

      it 'raises error when SUPPORT_EMAIL is missing' do
        ENV['SUPPORT_PHONE'] = '123-456-7890'
        ENV['CHAT_HOURS'] = '9am-5pm'

        expect do
          described_class.for_parent
        end.to raise_error(ContactOptions::ConfigurationError, /SUPPORT_EMAIL.*required/)
      end

      it 'raises error when CHAT_HOURS is missing' do
        ENV['SUPPORT_PHONE'] = '123-456-7890'
        ENV['SUPPORT_EMAIL'] = 'support@example.com'

        expect do
          described_class.for_parent
        end.to raise_error(ContactOptions::ConfigurationError, /CHAT_HOURS.*required/)
      end
    end
  end

  describe '.chat_hours_with_timezone' do
    after do
      ENV.delete('CHAT_HOURS')
      ENV.delete('CHAT_HOURS_TIMEZONE')
    end

    context 'when hours already include timezone' do
      it 'returns hours as-is for PT' do
        ENV['CHAT_HOURS'] = 'Monday-Friday 9am-5pm PT'
        result = described_class.chat_hours_with_timezone
        expect(result).to eq('Monday-Friday 9am-5pm PT')
      end

      it 'returns hours as-is for PST' do
        ENV['CHAT_HOURS'] = '9:00 AM - 5:00 PM PST'
        result = described_class.chat_hours_with_timezone
        expect(result).to eq('9:00 AM - 5:00 PM PST')
      end

      it 'returns hours as-is for ET' do
        ENV['CHAT_HOURS'] = 'Weekdays 9am-6pm ET'
        result = described_class.chat_hours_with_timezone
        expect(result).to eq('Weekdays 9am-6pm ET')
      end
    end

    context 'when hours do not include timezone' do
      it 'appends default Pacific timezone' do
        ENV['CHAT_HOURS'] = 'Monday-Friday 9am-5pm'
        result = described_class.chat_hours_with_timezone

        # Should append PST or PDT depending on current date
        expect(result).to match(/Monday-Friday 9am-5pm (PST|PDT)/)
      end

      it 'uses custom timezone from CHAT_HOURS_TIMEZONE' do
        ENV['CHAT_HOURS'] = '9am-5pm'
        ENV['CHAT_HOURS_TIMEZONE'] = 'America/New_York'
        result = described_class.chat_hours_with_timezone

        # Should append EST or EDT depending on current date
        expect(result).to match(/9am-5pm (EST|EDT)/)
      end
    end
  end

  describe '.configured?' do
    after do
      ENV.delete('SUPPORT_PHONE')
      ENV.delete('SUPPORT_EMAIL')
      ENV.delete('CHAT_HOURS')
    end

    it 'returns true when all options are configured' do
      ENV['SUPPORT_PHONE'] = '123-456-7890'
      ENV['SUPPORT_EMAIL'] = 'support@example.com'
      ENV['CHAT_HOURS'] = '9am-5pm'

      expect(described_class.configured?).to be true
    end

    it 'returns false when SUPPORT_PHONE is missing' do
      ENV['SUPPORT_EMAIL'] = 'support@example.com'
      ENV['CHAT_HOURS'] = '9am-5pm'

      expect(described_class.configured?).to be false
    end

    it 'returns false when SUPPORT_EMAIL is missing' do
      ENV['SUPPORT_PHONE'] = '123-456-7890'
      ENV['CHAT_HOURS'] = '9am-5pm'

      expect(described_class.configured?).to be false
    end

    it 'returns false when CHAT_HOURS is missing' do
      ENV['SUPPORT_PHONE'] = '123-456-7890'
      ENV['SUPPORT_EMAIL'] = 'support@example.com'

      expect(described_class.configured?).to be false
    end
  end

  describe 'phone validation' do
    before do
      ENV['SUPPORT_EMAIL'] = 'support@example.com'
      ENV['CHAT_HOURS'] = 'Monday-Friday 9am-5pm'
    end

    after do
      ENV.delete('SUPPORT_PHONE')
      ENV.delete('SUPPORT_EMAIL')
      ENV.delete('CHAT_HOURS')
    end

    context 'with valid phone formats' do
      it 'accepts E.164 format' do
        ENV['SUPPORT_PHONE'] = '+12345678900'
        expect { described_class.for_parent }.not_to raise_error
      end

      it 'accepts US domestic format with dashes' do
        ENV['SUPPORT_PHONE'] = '123-456-7890'
        expect { described_class.for_parent }.not_to raise_error
      end

      it 'accepts US domestic format with parentheses' do
        ENV['SUPPORT_PHONE'] = '(123) 456-7890'
        expect { described_class.for_parent }.not_to raise_error
      end

      it 'accepts US format with country code' do
        ENV['SUPPORT_PHONE'] = '1-123-456-7890'
        expect { described_class.for_parent }.not_to raise_error
      end

      it 'accepts toll-free vanity numbers' do
        ENV['SUPPORT_PHONE'] = '1-800-DAYBREAK'
        expect { described_class.for_parent }.not_to raise_error
      end

      it 'accepts toll-free numeric' do
        ENV['SUPPORT_PHONE'] = '1-800-123-4567'
        expect { described_class.for_parent }.not_to raise_error
      end
    end

    context 'with invalid phone formats' do
      it 'rejects plain numbers without formatting' do
        ENV['SUPPORT_PHONE'] = '1234567890'
        expect do
          described_class.for_parent
        end.to raise_error(ContactOptions::ConfigurationError, /SUPPORT_PHONE format invalid/)
      end

      it 'rejects incomplete numbers' do
        ENV['SUPPORT_PHONE'] = '123-456'
        expect do
          described_class.for_parent
        end.to raise_error(ContactOptions::ConfigurationError, /SUPPORT_PHONE format invalid/)
      end

      it 'rejects random text' do
        ENV['SUPPORT_PHONE'] = 'call us'
        expect do
          described_class.for_parent
        end.to raise_error(ContactOptions::ConfigurationError, /SUPPORT_PHONE format invalid/)
      end
    end
  end

  describe 'email validation' do
    before do
      ENV['SUPPORT_PHONE'] = '123-456-7890'
      ENV['CHAT_HOURS'] = 'Monday-Friday 9am-5pm'
    end

    after do
      ENV.delete('SUPPORT_PHONE')
      ENV.delete('SUPPORT_EMAIL')
      ENV.delete('CHAT_HOURS')
    end

    context 'with valid email formats' do
      it 'accepts standard email' do
        ENV['SUPPORT_EMAIL'] = 'support@example.com'
        expect { described_class.for_parent }.not_to raise_error
      end

      it 'accepts email with subdomain' do
        ENV['SUPPORT_EMAIL'] = 'support@mail.example.com'
        expect { described_class.for_parent }.not_to raise_error
      end

      it 'accepts email with plus addressing' do
        ENV['SUPPORT_EMAIL'] = 'support+escalation@example.com'
        expect { described_class.for_parent }.not_to raise_error
      end

      it 'accepts email with dots in local part' do
        ENV['SUPPORT_EMAIL'] = 'care.team@example.com'
        expect { described_class.for_parent }.not_to raise_error
      end
    end

    context 'with invalid email formats' do
      it 'rejects email without @' do
        ENV['SUPPORT_EMAIL'] = 'supportexample.com'
        expect do
          described_class.for_parent
        end.to raise_error(ContactOptions::ConfigurationError, /SUPPORT_EMAIL format invalid/)
      end

      it 'rejects email without domain' do
        ENV['SUPPORT_EMAIL'] = 'support@'
        expect do
          described_class.for_parent
        end.to raise_error(ContactOptions::ConfigurationError, /SUPPORT_EMAIL format invalid/)
      end

      it 'rejects email without TLD' do
        ENV['SUPPORT_EMAIL'] = 'support@example'
        expect do
          described_class.for_parent
        end.to raise_error(ContactOptions::ConfigurationError, /SUPPORT_EMAIL format invalid/)
      end

      it 'rejects plain text' do
        ENV['SUPPORT_EMAIL'] = 'email us'
        expect do
          described_class.for_parent
        end.to raise_error(ContactOptions::ConfigurationError, /SUPPORT_EMAIL format invalid/)
      end
    end
  end

  describe 'chat hours validation' do
    before do
      ENV['SUPPORT_PHONE'] = '123-456-7890'
      ENV['SUPPORT_EMAIL'] = 'support@example.com'
    end

    after do
      ENV.delete('SUPPORT_PHONE')
      ENV.delete('SUPPORT_EMAIL')
      ENV.delete('CHAT_HOURS')
    end

    it 'accepts descriptive hours' do
      ENV['CHAT_HOURS'] = 'Monday-Friday 9am-5pm PT'
      expect { described_class.for_parent }.not_to raise_error
    end

    it 'accepts 24/7 format' do
      ENV['CHAT_HOURS'] = '24/7'
      expect { described_class.for_parent }.not_to raise_error
    end

    it 'accepts time range format' do
      ENV['CHAT_HOURS'] = '9:00 AM - 5:00 PM'
      expect { described_class.for_parent }.not_to raise_error
    end

    it 'rejects very short strings' do
      ENV['CHAT_HOURS'] = 'AM'
      expect do
        described_class.for_parent
      end.to raise_error(ContactOptions::ConfigurationError, /CHAT_HOURS must be a descriptive string/)
    end

    it 'rejects empty strings' do
      ENV['CHAT_HOURS'] = ''
      expect do
        described_class.for_parent
      end.to raise_error(ContactOptions::ConfigurationError, /CHAT_HOURS.*required/)
    end
  end
end
