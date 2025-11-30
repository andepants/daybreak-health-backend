# frozen_string_literal: true

module Eligibility
  # Factory class for selecting the appropriate eligibility adapter
  #
  # The factory uses the payer name to select the most appropriate adapter
  # for eligibility verification. Currently, all payers use the generic
  # EDI adapter, but this design allows for payer-specific adapters in the future.
  #
  # @example Get adapter for an insurance record
  #   adapter = AdapterFactory.adapter_for(insurance)
  #   result = adapter.verify_eligibility(insurance)
  #
  # @example Future payer-specific adapter (planned)
  #   # When Aetna API integration is added:
  #   # AdapterFactory will return AetnaAdapter for Aetna insurance
  #
  # @see Eligibility::BaseAdapter
  # @see Eligibility::EdiAdapter
  class AdapterFactory
    # Payer-to-adapter mappings for future custom integrations
    # Currently all payers use the generic EDI adapter
    PAYER_ADAPTERS = {
      # Future: direct API integrations
      # "Aetna" => "Eligibility::AetnaAdapter",
      # "UnitedHealthcare" => "Eligibility::UnitedAdapter",
      # "Blue Cross Blue Shield" => "Eligibility::BcbsAdapter",
      # "Cigna" => "Eligibility::CignaAdapter",
      # "Humana" => "Eligibility::HumanaAdapter",
    }.freeze

    class << self
      # Get the appropriate adapter for an insurance record
      #
      # @param insurance [Insurance] The insurance record
      # @return [BaseAdapter] An adapter instance for eligibility verification
      def adapter_for(insurance)
        adapter_class = find_adapter_class(insurance.payer_name)
        adapter_class.new
      end

      # Check if a payer has a custom adapter
      #
      # @param payer_name [String] The payer name
      # @return [Boolean] True if custom adapter exists
      def custom_adapter?(payer_name)
        PAYER_ADAPTERS.key?(normalize_payer_name(payer_name))
      end

      # Get list of payers with custom adapters
      #
      # @return [Array<String>] List of payer names with custom integrations
      def payers_with_custom_adapters
        PAYER_ADAPTERS.keys
      end

      private

      # Find the adapter class for a payer
      #
      # @param payer_name [String] The payer name
      # @return [Class] Adapter class to use
      def find_adapter_class(payer_name)
        normalized_name = normalize_payer_name(payer_name)
        adapter_class_name = PAYER_ADAPTERS[normalized_name]

        if adapter_class_name.present?
          begin
            adapter_class_name.constantize
          rescue NameError => e
            Rails.logger.warn("Adapter class not found for #{payer_name}: #{e.message}, falling back to EDI")
            EdiAdapter
          end
        else
          # Default to generic EDI adapter for all payers
          EdiAdapter
        end
      end

      # Normalize payer name for lookup
      #
      # @param payer_name [String] The payer name
      # @return [String] Normalized payer name
      def normalize_payer_name(payer_name)
        payer_name.to_s.strip
      end
    end
  end
end
