# frozen_string_literal: true

module Eligibility
  # Generic EDI 270/271 adapter for insurance eligibility verification
  #
  # This adapter implements the HIPAA X12 EDI 270/271 transaction set for
  # real-time eligibility inquiries. It works with most EDI clearinghouses
  # and payers that support the standard X12 format.
  #
  # EDI 270 (Eligibility Inquiry):
  # - Sends member information to query coverage
  # - Includes service type codes for mental health services
  #
  # EDI 271 (Eligibility Response):
  # - Receives coverage information (copay, deductible, coinsurance)
  # - Parses EB (Eligibility/Benefit) segments
  # - Handles AAA (Error) segments for failure cases
  #
  # @example Verify eligibility
  #   adapter = EdiAdapter.new
  #   result = adapter.verify_eligibility(insurance)
  #   result["status"] # => "VERIFIED"
  #   result["coverage"]["mental_health_covered"] # => true
  #
  # @see https://www.cms.gov/regulations-and-guidance/administrative-simplification/hipaa-aca/eligibility-benefit-inquiry-and-response
  class EdiAdapter < BaseAdapter
    # EDI service type codes
    SERVICE_TYPE_HEALTH_BENEFIT = "30"
    SERVICE_TYPE_MENTAL_HEALTH = "MH"

    # EDI error code mappings
    ERROR_MAPPINGS = {
      "42" => { category: :invalid_member_id, message: "Member ID not found", retryable: false },
      "33" => { category: :invalid_member_id, message: "Invalid date of birth", retryable: false },
      "56" => { category: :coverage_not_active, message: "Coverage not active", retryable: false },
      "57" => { category: :coverage_not_active, message: "Coverage terminated", retryable: false },
      "58" => { category: :service_not_covered, message: "Service not covered", retryable: false },
      "72" => { category: :network_error, message: "Unable to respond at this time", retryable: true },
      "73" => { category: :network_error, message: "System currently unavailable", retryable: true },
      "75" => { category: :unknown, message: "Subscriber/insured not found", retryable: false }
    }.freeze

    # Verify eligibility for the given insurance record
    #
    # @param insurance [Insurance] The insurance record to verify
    # @return [Hash] Verification result
    def verify_eligibility(insurance)
      Timeout.timeout(TIMEOUT_SECONDS) do
        # Build EDI 270 request
        edi_request = build_edi_270(insurance)

        # Send EDI transaction to clearinghouse
        edi_response = send_edi_transaction(edi_request)

        # Parse EDI 271 response
        parse_edi_271(edi_response)
      end
    rescue Timeout::Error
      Rails.logger.error("EDI verification timeout for insurance #{insurance.id}")
      build_verification_result(
        eligible: nil,
        coverage: {},
        error: timeout_error
      )
    rescue Faraday::Error, Net::OpenTimeout, SocketError => e
      Rails.logger.error("EDI verification network error: #{e.message}")
      build_verification_result(
        eligible: nil,
        coverage: {},
        error: network_error(e)
      )
    rescue StandardError => e
      Rails.logger.error("EDI verification failed: #{e.class} - #{e.message}")
      build_verification_result(
        eligible: false,
        coverage: {},
        error: build_error(
          category: :unknown,
          message: "Verification processing error",
          retryable: true
        )
      )
    end

    private

    # Build EDI 270 eligibility inquiry request
    #
    # @param insurance [Insurance] The insurance record
    # @return [Hash] EDI 270 request structure
    def build_edi_270(insurance)
      control_number = generate_control_number
      trace_id = generate_trace_id
      current_time = Time.current

      {
        transaction_set: "270",
        control_number: control_number,
        trace_id: trace_id,
        created_at: current_time.iso8601,
        segments: [
          # ST - Transaction Set Header
          build_segment("ST", ["270", control_number]),

          # BHT - Beginning of Hierarchical Transaction
          build_segment("BHT", [
            "0022",                              # Hierarchical structure code
            "13",                                # Purpose: Request
            trace_id,                            # Reference identification
            current_time.strftime("%Y%m%d"),     # Transaction date
            current_time.strftime("%H%M")        # Transaction time
          ]),

          # HL - Information Source (Payer) - Level 1
          build_segment("HL", ["1", "", "20", "1"]),

          # NM1 - Payer Name
          build_segment("NM1", [
            "PR",                                # Entity: Payer
            "2",                                 # Organization
            normalize_payer_name(insurance.payer_name),
            "",                                  # First name (empty for org)
            "",                                  # Middle name
            "",                                  # Prefix
            "",                                  # Suffix
            "PI",                                # ID code qualifier: Payer ID
            payer_id_for(insurance)              # Payer ID
          ]),

          # HL - Information Receiver (Provider) - Level 2
          build_segment("HL", ["2", "1", "21", "1"]),

          # NM1 - Provider Name
          build_segment("NM1", [
            "1P",                                # Entity: Provider
            "2",                                 # Organization
            provider_name,
            "",
            "",
            "",
            "",
            "XX",                                # ID code qualifier: NPI
            provider_npi
          ]),

          # HL - Subscriber - Level 3
          build_segment("HL", ["3", "2", "22", "0"]),

          # NM1 - Subscriber Name
          build_segment("NM1", [
            "IL",                                # Entity: Insured/Subscriber
            "1",                                 # Person
            extract_last_name(insurance.subscriber_name),
            extract_first_name(insurance.subscriber_name),
            "",                                  # Middle name
            "",
            "",
            "MI",                                # ID code qualifier: Member ID
            insurance.member_id
          ]),

          # REF - Member ID Reference
          build_segment("REF", [
            "0F",                                # Reference qualifier: Subscriber Number
            insurance.member_id
          ]),

          # REF - Group Number Reference
          (build_segment("REF", [
            "1L",                                # Reference qualifier: Group or Policy Number
            insurance.group_number
          ]) if insurance.group_number.present?),

          # DMG - Subscriber Demographics (DOB)
          (build_segment("DMG", [
            "D8",                                # Date format: CCYYMMDD
            format_date(insurance.subscriber_dob)
          ]) if insurance.subscriber_dob.present?),

          # DTP - Service Date
          build_segment("DTP", [
            "291",                               # Qualifier: Plan
            "D8",                                # Date format
            current_time.strftime("%Y%m%d")      # Service date
          ]),

          # EQ - Eligibility Inquiry (Health Benefit Plan)
          build_segment("EQ", [SERVICE_TYPE_HEALTH_BENEFIT]),

          # EQ - Eligibility Inquiry (Mental Health - specific)
          build_segment("EQ", [SERVICE_TYPE_MENTAL_HEALTH]),

          # SE - Transaction Set Trailer
          build_segment("SE", [
            calculate_segment_count.to_s,
            control_number
          ])
        ].compact
      }
    end

    # Send EDI transaction to clearinghouse
    #
    # @param edi_request [Hash] The EDI 270 request
    # @return [Hash] The EDI 271 response
    def send_edi_transaction(edi_request)
      # In production, this would send to an actual EDI clearinghouse
      # For MVP, we simulate a response based on configured test mode
      if Rails.env.test? || edi_test_mode?
        simulate_edi_response(edi_request)
      else
        call_edi_clearinghouse(edi_request)
      end
    end

    # Call the actual EDI clearinghouse API
    #
    # @param edi_request [Hash] The EDI 270 request
    # @return [Hash] The EDI 271 response from clearinghouse
    def call_edi_clearinghouse(edi_request)
      response = edi_client.post(edi_endpoint) do |req|
        req.headers["Content-Type"] = "application/json"
        req.headers["Authorization"] = "Bearer #{edi_api_key}"
        req.body = {
          transaction: format_edi_for_transmission(edi_request),
          trace_id: edi_request[:trace_id]
        }.to_json
      end

      if response.success?
        parse_clearinghouse_response(response.body)
      else
        Rails.logger.error("EDI clearinghouse error: #{response.status} - #{response.body}")
        raise StandardError, "Clearinghouse returned error: #{response.status}"
      end
    end

    # Parse EDI 271 response
    #
    # @param edi_response [Hash] The EDI 271 response
    # @return [Hash] Verification result
    def parse_edi_271(edi_response)
      segments = edi_response[:segments] || []

      # Check for AAA error segments first
      aaa_segments = segments.select { |s| s[:segment] == "AAA" }
      if aaa_segments.any?
        return handle_edi_errors(aaa_segments)
      end

      # Find EB (Eligibility/Benefit) segments
      eb_segments = segments.select { |s| s[:segment] == "EB" }

      if eb_segments.empty?
        # No EB segments - unclear response, flag for manual review
        return build_verification_result(
          eligible: nil,
          coverage: {},
          error: build_error(
            category: :unknown,
            message: "No eligibility information in response",
            retryable: true  # Changed to true to trigger MANUAL_REVIEW status
          )
        )
      end

      # Extract coverage information
      mental_health_coverage = extract_mental_health_coverage(eb_segments)
      general_coverage = extract_general_coverage(eb_segments)

      # Determine eligibility based on mental health coverage specifically
      eligible = mental_health_coverage.present?
      mental_health_covered = mental_health_coverage.present?

      # If no mental health coverage but general health coverage exists,
      # flag for manual review (AC4)
      if !mental_health_covered && general_coverage.present?
        return build_verification_result(
          eligible: nil,
          coverage: build_coverage(
            mental_health_covered: false,
            copay: extract_copay_from_segments(eb_segments),
            deductible: extract_deductible(eb_segments),
            coinsurance: extract_coinsurance(eb_segments),
            effective_date: extract_effective_date(segments),
            termination_date: extract_termination_date(segments)
          ),
          error: build_error(
            category: :unknown,
            message: "Mental health coverage unclear - general coverage exists",
            retryable: true,  # Requires manual review, so marked as "retryable" for MANUAL_REVIEW status
            code: "MENTAL_HEALTH_UNCLEAR"
          )
        )
      end

      # Build successful verification result
      build_verification_result(
        eligible: eligible,
        coverage: build_coverage(
          mental_health_covered: mental_health_covered,
          copay: extract_copay_from_segments(eb_segments),
          deductible: extract_deductible(eb_segments),
          coinsurance: extract_coinsurance(eb_segments),
          effective_date: extract_effective_date(segments),
          termination_date: extract_termination_date(segments)
        )
      )
    end

    # Handle EDI AAA error segments
    #
    # @param aaa_segments [Array<Hash>] AAA error segments
    # @return [Hash] Verification result with error
    def handle_edi_errors(aaa_segments)
      # Get the first error code
      error_segment = aaa_segments.first
      error_code = error_segment[:elements]&.fetch(1, nil)

      error_mapping = ERROR_MAPPINGS[error_code] || {
        category: :unknown,
        message: "Unknown error code: #{error_code}",
        retryable: false
      }

      build_verification_result(
        eligible: false,
        coverage: {},
        error: build_error(
          category: error_mapping[:category],
          message: error_mapping[:message],
          retryable: error_mapping[:retryable],
          code: "AAA#{error_code}"
        )
      )
    end

    # Extract mental health coverage from EB segments
    #
    # @param eb_segments [Array<Hash>] EB segments
    # @return [Hash, nil] Mental health coverage segment or nil
    def extract_mental_health_coverage(eb_segments)
      eb_segments.find do |seg|
        elements = seg[:elements] || []
        service_type = elements[3]

        # Service type MH or includes mental health CPT codes
        service_type == SERVICE_TYPE_MENTAL_HEALTH ||
          mental_health_cpt_code?(elements)
      end
    end

    # Extract general health coverage from EB segments
    #
    # @param eb_segments [Array<Hash>] EB segments
    # @return [Hash, nil] General coverage segment or nil
    def extract_general_coverage(eb_segments)
      eb_segments.find do |seg|
        elements = seg[:elements] || []
        eligibility_code = elements[0]
        service_type = elements[3]

        # Active coverage (1 = Active, 6 = Inactive)
        eligibility_code == "1" &&
          (service_type == SERVICE_TYPE_HEALTH_BENEFIT || service_type.blank?)
      end
    end

    # Check if EB segment contains mental health CPT codes
    #
    # @param elements [Array] EB segment elements
    # @return [Boolean] True if mental health CPT codes present
    def mental_health_cpt_code?(elements)
      # CPT codes 90791-90899 are psychiatric services
      procedure_code = elements[13]
      return false unless procedure_code

      code_num = procedure_code.to_i
      code_num >= 90791 && code_num <= 90899
    end

    # Extract copay from EB segments
    #
    # @param eb_segments [Array<Hash>] EB segments
    # @return [Hash, nil] Copay structure
    def extract_copay_from_segments(eb_segments)
      # Find copay segment (EB01 = B for co-payment)
      copay_segment = eb_segments.find do |seg|
        seg[:elements]&.first == "B"
      end

      return nil unless copay_segment

      elements = copay_segment[:elements] || []
      # EB07 is the monetary amount for copay
      amount = elements[6]&.to_f
      build_copay(amount: amount) if amount&.positive?
    end

    # Extract deductible from EB segments
    #
    # @param eb_segments [Array<Hash>] EB segments
    # @return [Hash, nil] Deductible structure
    def extract_deductible(eb_segments)
      # Find deductible segment (EB01 = C for deductible)
      deductible_segment = eb_segments.find do |seg|
        seg[:elements]&.first == "C"
      end

      return nil unless deductible_segment

      elements = deductible_segment[:elements] || []
      amount = elements[6]&.to_f

      # Find amount met in separate segment if available
      met_segment = eb_segments.find do |seg|
        seg[:elements]&.first == "C" && seg[:elements]&.[](5) == "29" # 29 = Remaining
      end
      remaining = met_segment&.dig(:elements, 6)&.to_f || 0

      met = amount - remaining if amount && remaining

      build_deductible(amount: amount || 0, met: met || 0)
    end

    # Extract coinsurance from EB segments
    #
    # @param eb_segments [Array<Hash>] EB segments
    # @return [Hash, nil] Coinsurance structure
    def extract_coinsurance(eb_segments)
      # Find coinsurance segment (EB01 = A for coinsurance)
      coinsurance_segment = eb_segments.find do |seg|
        seg[:elements]&.first == "A"
      end

      return nil unless coinsurance_segment

      elements = coinsurance_segment[:elements] || []
      # EB08 is the percentage for coinsurance
      percentage = elements[7]&.to_f

      build_coinsurance(percentage: (percentage * 100).to_i) if percentage
    end

    # Extract effective date from segments
    #
    # @param segments [Array<Hash>] All segments
    # @return [String, nil] ISO date string
    def extract_effective_date(segments)
      dtp_segment = segments.find do |seg|
        seg[:segment] == "DTP" && seg[:elements]&.first == "348" # 348 = Effective Date
      end

      return nil unless dtp_segment

      date_str = dtp_segment[:elements]&.[](2)
      parse_edi_date(date_str)
    end

    # Extract termination date from segments
    #
    # @param segments [Array<Hash>] All segments
    # @return [String, nil] ISO date string
    def extract_termination_date(segments)
      dtp_segment = segments.find do |seg|
        seg[:segment] == "DTP" && seg[:elements]&.first == "349" # 349 = Termination Date
      end

      return nil unless dtp_segment

      date_str = dtp_segment[:elements]&.[](2)
      parse_edi_date(date_str)
    end

    # Simulate EDI response for testing/development
    #
    # @param edi_request [Hash] The EDI 270 request
    # @return [Hash] Simulated EDI 271 response
    def simulate_edi_response(edi_request)
      # Check for test scenarios based on member ID
      member_id = extract_member_id_from_request(edi_request)

      case member_id
      when /INVALID/i
        simulate_error_response("42") # Invalid member ID
      when /INACTIVE/i
        simulate_error_response("56") # Coverage not active
      when /NOMENTAL/i
        simulate_no_mental_health_response
      when /TIMEOUT/i
        sleep(TIMEOUT_SECONDS + 1) # Force timeout
      else
        simulate_success_response
      end
    end

    # Simulate successful eligibility response
    #
    # @return [Hash] Simulated EDI 271 success response
    def simulate_success_response
      {
        segments: [
          build_segment("EB", [
            "1",                    # Active coverage
            "IND",                  # Individual
            "",
            SERVICE_TYPE_MENTAL_HEALTH
          ]),
          build_segment("EB", [
            "B",                    # Co-payment
            "IND",
            "",
            SERVICE_TYPE_MENTAL_HEALTH,
            "",
            "",
            "25.00"                 # Copay amount
          ]),
          build_segment("EB", [
            "C",                    # Deductible
            "IND",
            "",
            SERVICE_TYPE_HEALTH_BENEFIT,
            "",
            "",
            "500.00"                # Deductible amount
          ]),
          build_segment("EB", [
            "A",                    # Coinsurance
            "IND",
            "",
            SERVICE_TYPE_HEALTH_BENEFIT,
            "",
            "",
            "",
            "0.20"                  # 20% coinsurance
          ]),
          build_segment("DTP", ["348", "D8", Time.current.strftime("%Y%m%d")]) # Effective date
        ]
      }
    end

    # Simulate error response
    #
    # @param error_code [String] EDI error code
    # @return [Hash] Simulated EDI 271 error response
    def simulate_error_response(error_code)
      {
        segments: [
          build_segment("AAA", ["Y", error_code, "", "C"])
        ]
      }
    end

    # Simulate response with no mental health coverage
    #
    # @return [Hash] Simulated EDI 271 response without mental health
    def simulate_no_mental_health_response
      {
        segments: [
          build_segment("EB", [
            "1",                    # Active coverage
            "IND",
            "",
            SERVICE_TYPE_HEALTH_BENEFIT # General health only
          ])
        ]
      }
    end

    # Extract member ID from EDI request
    #
    # @param edi_request [Hash] The EDI 270 request
    # @return [String, nil] Member ID
    def extract_member_id_from_request(edi_request)
      ref_segment = edi_request[:segments]&.find do |seg|
        seg[:segment] == "REF" && seg[:elements]&.first == "0F"
      end

      ref_segment&.dig(:elements, 1)
    end

    # Helper methods

    def build_segment(name, elements)
      { segment: name, elements: elements }
    end

    def generate_control_number
      format("%09d", rand(1..999_999_999))
    end

    def generate_trace_id
      "DYBK#{Time.current.strftime('%Y%m%d%H%M%S')}#{rand(1000..9999)}"
    end

    def calculate_segment_count
      14 # Approximate segment count for standard 270
    end

    def payer_id_for(insurance)
      return insurance.payer_id if insurance.respond_to?(:payer_id) && insurance.payer_id.present?

      ""
    end

    def normalize_payer_name(name)
      name.to_s.upcase.gsub(/[^A-Z0-9\s]/, "").strip.truncate(35)
    end

    def extract_first_name(full_name)
      full_name.to_s.split.first || ""
    end

    def extract_last_name(full_name)
      parts = full_name.to_s.split
      parts.length > 1 ? parts.last : parts.first || ""
    end

    def format_date(date_str)
      return "" unless date_str

      Date.parse(date_str).strftime("%Y%m%d")
    rescue Date::Error
      ""
    end

    def parse_edi_date(date_str)
      return nil unless date_str && date_str.length == 8

      Date.strptime(date_str, "%Y%m%d").iso8601
    rescue Date::Error
      nil
    end

    def provider_name
      Rails.application.credentials.dig(:edi, :provider_name) || "DAYBREAK HEALTH"
    end

    def provider_npi
      Rails.application.credentials.dig(:edi, :npi_number) || ENV.fetch("PROVIDER_NPI", "")
    end

    def edi_endpoint
      Rails.application.credentials.dig(:edi, :endpoint) || ENV.fetch("EDI_ENDPOINT", "")
    end

    def edi_api_key
      Rails.application.credentials.dig(:edi, :api_key) || ENV.fetch("EDI_API_KEY", "")
    end

    def edi_test_mode?
      Rails.application.credentials.dig(:edi, :test_mode) == true ||
        ENV.fetch("EDI_TEST_MODE", "false") == "true"
    end

    def edi_client
      @edi_client ||= Faraday.new do |conn|
        conn.options.timeout = TIMEOUT_SECONDS
        conn.options.open_timeout = 10
        conn.adapter Faraday.default_adapter
      end
    end

    def format_edi_for_transmission(edi_request)
      # Convert hash structure to X12 EDI format
      edi_request[:segments].map do |seg|
        [seg[:segment], *seg[:elements]].join("*")
      end.join("~")
    end

    def parse_clearinghouse_response(body)
      data = JSON.parse(body)
      # Convert X12 format back to segment hash structure
      edi_string = data["response"] || data["edi_response"] || ""

      segments = edi_string.split("~").map do |segment_str|
        parts = segment_str.split("*")
        { segment: parts.first, elements: parts[1..] }
      end

      { segments: segments }
    rescue JSON::ParserError
      { segments: [] }
    end
  end
end
