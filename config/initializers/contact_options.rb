# frozen_string_literal: true

# Contact Options Configuration
# AC 3.5.4: Provide contact options to parent (phone, email, chat hours)
#
# Environment Variables:
# - SUPPORT_PHONE: Support phone number (E.164 format recommended)
# - SUPPORT_EMAIL: Support email address
# - CHAT_HOURS: Chat availability hours (timezone-aware)
module ContactOptions
  class ConfigurationError < StandardError; end

  class << self
    # Get formatted contact options for parents
    # AC 3.5.4: Returns phone, email, chat hours from environment
    #
    # @return [Hash] Contact information
    # @raise [ConfigurationError] If configuration is invalid or missing
    def for_parent
      validate_configuration!

      {
        phone: ENV.fetch('SUPPORT_PHONE'),
        email: ENV.fetch('SUPPORT_EMAIL'),
        chat_hours: chat_hours_with_timezone
      }
    end

    # Get chat hours with timezone awareness
    # AC 3.5.4: Timezone-aware chat hours display
    #
    # @return [String] Chat hours with timezone
    def chat_hours_with_timezone
      raw_hours = ENV.fetch('CHAT_HOURS')
      timezone = ENV.fetch('CHAT_HOURS_TIMEZONE', 'America/Los_Angeles')

      # If hours already include timezone info, return as-is
      return raw_hours if raw_hours.match?(/\b(PT|ET|MT|CT|PST|EST|MST|CST)\b/i)

      # Otherwise append timezone abbreviation
      tz = ActiveSupport::TimeZone[timezone]
      "#{raw_hours} #{tz.tzinfo.current_period.abbreviation}"
    end

    # Check if contact options are configured
    # @return [Boolean] True if all required options are present
    def configured?
      ENV['SUPPORT_PHONE'].present? &&
        ENV['SUPPORT_EMAIL'].present? &&
        ENV['CHAT_HOURS'].present?
    end

    private

    # Validate contact options configuration
    # @raise [ConfigurationError] If validation fails
    def validate_configuration!
      validate_phone!(ENV['SUPPORT_PHONE'])
      validate_email!(ENV['SUPPORT_EMAIL'])
      validate_chat_hours!(ENV['CHAT_HOURS'])
    end

    # Validate phone number format
    # Accepts various formats: E.164, US domestic, toll-free
    #
    # @param phone [String] Phone number to validate
    # @raise [ConfigurationError] If phone is invalid
    def validate_phone!(phone)
      if phone.blank?
        raise ConfigurationError, 'SUPPORT_PHONE environment variable is required'
      end

      # Allow E.164 format (+1234567890), US domestic (123-456-7890, (123) 456-7890),
      # and toll-free (1-800-XXX-XXXX)
      valid_formats = [
        /^\+\d{1,3}\d{10}$/,                           # E.164: +12345678900
        /^\d{3}-\d{3}-\d{4}$/,                         # US: 123-456-7890
        /^\(\d{3}\)\s*\d{3}-\d{4}$/,                   # US: (123) 456-7890
        /^1-\d{3}-\d{3}-\d{4}$/,                       # US with country: 1-123-456-7890
        /^1-\d{3}-[A-Z0-9]{3,4}-?[A-Z0-9]{0,4}$/i      # Toll-free vanity: 1-800-DAYBREAK or 1-800-123-4567
      ]

      # Remove spaces for validation
      normalized_phone = phone.gsub(/\s+/, '')

      unless valid_formats.any? { |format| normalized_phone.match?(format) }
        raise ConfigurationError,
              "SUPPORT_PHONE format invalid: #{phone}. " \
              'Expected formats: +12345678900, 123-456-7890, (123) 456-7890, or 1-800-DAYBREAK'
      end
    end

    # Validate email address format
    #
    # @param email [String] Email address to validate
    # @raise [ConfigurationError] If email is invalid
    def validate_email!(email)
      if email.blank?
        raise ConfigurationError, 'SUPPORT_EMAIL environment variable is required'
      end

      # Basic email format validation
      unless email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
        raise ConfigurationError, "SUPPORT_EMAIL format invalid: #{email}"
      end
    end

    # Validate chat hours format
    #
    # @param hours [String] Chat hours to validate
    # @raise [ConfigurationError] If hours are invalid
    def validate_chat_hours!(hours)
      if hours.blank?
        raise ConfigurationError, 'CHAT_HOURS environment variable is required'
      end

      # Just check that it's not empty - allow flexible format
      # Examples: "Monday-Friday 9am-5pm", "24/7", "9:00 AM - 5:00 PM PST"
      if hours.length < 3
        raise ConfigurationError, 'CHAT_HOURS must be a descriptive string (e.g., "Monday-Friday 9am-5pm PT")'
      end
    end
  end
end
