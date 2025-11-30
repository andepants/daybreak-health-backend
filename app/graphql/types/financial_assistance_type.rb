# frozen_string_literal: true

module Types
  # GraphQL type for financial assistance program information
  #
  # Exposes information about financial assistance eligibility, application process,
  # and sliding scale discounts available to families based on household income.
  #
  # Configuration loaded from config/financial_assistance.yml
  class FinancialAssistanceType < Types::BaseObject
    description "Financial assistance program information"

    field :available, Boolean, null: false,
          description: "Whether financial assistance program is available"

    field :eligibility_criteria, [ String ], null: false,
          description: "List of eligibility requirements"

    field :application_url, String, null: false,
          description: "URL for hardship consideration application"

    field :description, String, null: false,
          description: "Program description and information"

    field :sliding_scale_available, Boolean, null: false,
          description: "Whether sliding scale discounts are available"

    field :discount_range, String, null: false,
          description: "Range of available discounts (e.g., '20-75%')"

    field :additional_info, [ String ], null: true,
          description: "Additional program information and details"

    # Resolve fields from configuration
    def available
      config[:available] || false
    end

    def eligibility_criteria
      config[:eligibility_criteria] || []
    end

    def application_url
      config[:application_url] || ""
    end

    def description
      config[:program_description] || "Financial assistance information not available"
    end

    def sliding_scale_available
      config[:sliding_scale_discounts].present?
    end

    def discount_range
      return "Not available" unless config[:sliding_scale_discounts].present?

      discounts = config[:sliding_scale_discounts].values
      min_discount = discounts.min
      max_discount = discounts.max

      "#{min_discount}-#{max_discount}%"
    end

    def additional_info
      config[:additional_info]
    end

    private

    def config
      @config ||= Rails.application.config.financial_assistance || {}
    end
  end
end
