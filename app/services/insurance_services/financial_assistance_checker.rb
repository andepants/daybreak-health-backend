# frozen_string_literal: true

module InsuranceServices
  # Checks eligibility for financial assistance programs
  # MVP: Shows financial assistance info to everyone, let assistance team determine final eligibility
  class FinancialAssistanceChecker
    def initialize(session, config: Rails.configuration.self_pay)
      @session = session
      @config = config
    end

    # Check if financial assistance should be shown
    #
    # @return [Boolean] True if assistance info should be displayed
    def eligible?
      # MVP: Show to everyone - assistance team will determine final eligibility
      assistance_enabled?
    end

    # Get contact information for financial assistance
    #
    # @return [Hash, nil] Contact details or nil if not available
    def contact_info
      return nil unless assistance_enabled?

      @config.dig(:financial_assistance, :contact)
    end

    # Get formatted assistance information string
    #
    # @return [String, nil] Formatted message with contact details
    def formatted_info
      return nil unless eligible?

      contact = contact_info
      return nil unless contact

      "#{contact[:description]}\n\nContact: #{contact[:phone]} or #{contact[:email]}"
    end

    private

    def assistance_enabled?
      @config.dig(:financial_assistance, :enabled) == true
    end
  end
end
