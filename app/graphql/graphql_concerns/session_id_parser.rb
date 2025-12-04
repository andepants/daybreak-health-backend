# frozen_string_literal: true

module GraphqlConcerns
  # Module for parsing session IDs in various formats
  #
  # Handles conversion between sess_ prefixed hex format and UUID format
  module SessionIdParser
    extend self

    # Parse session ID from various formats to UUID
    #
    # Supports:
    # - sess_[hex] format (converts to UUID)
    # - UUID format (returns as-is)
    #
    # @param session_id [String] The session ID in any supported format
    # @return [String] The session ID in UUID format
    # @example
    #   parse_session_id("sess_1234567890abcdef1234567890abcdef")
    #   # => "12345678-90ab-cdef-1234-567890abcdef"
    #
    #   parse_session_id("12345678-90ab-cdef-1234-567890abcdef")
    #   # => "12345678-90ab-cdef-1234-567890abcdef"
    def parse_session_id(session_id)
      # Strip sess_ prefix and convert back to UUID format if needed
      if session_id.start_with?("sess_")
        hex = session_id.sub("sess_", "")
        "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
      else
        session_id
      end
    end

    # Format UUID session ID to sess_ prefixed hex format
    #
    # @param session_id [String] The session ID (UUID or already formatted)
    # @return [String] The session ID in sess_ prefixed hex format
    # @example
    #   format_session_id("12345678-90ab-cdef-1234-567890abcdef")
    #   # => "sess_1234567890abcdef1234567890abcdef"
    #
    #   format_session_id("sess_1234567890abcdef1234567890abcdef")
    #   # => "sess_1234567890abcdef1234567890abcdef"
    def format_session_id(session_id)
      return session_id if session_id.start_with?("sess_")

      hex = session_id.delete("-")
      "sess_#{hex}"
    end
  end
end
