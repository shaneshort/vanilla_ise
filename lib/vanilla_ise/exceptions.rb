# frozen_string_literal: true

module VanillaIse
  class Error < StandardError; end

  class CSRFRequired < Error; end

  class CSRFTokenExpired < Error; end

  class NotFound < Error; end

  class InvalidRequest < Error; end

  # This error often raised when the response from the Cisco ISE API is not understood or an invalid
  # response. This is usually due to a malformed request.
  # @attr_reader [Hash] parsed_response The parsed response from the API.
  # @param [HTTParty::Response] response The raw response from the API.
  # @param [String] message The error message to display.
  # return [VanillaIse::InvalidResponse]
  class InvalidResponse < Error
    attr_reader :parsed_response

    def initialize(response, message: 'An unknown error was encountered when submitting the data to Cisco ISE. Please try again.')
      @parsed_response = response.parsed_response
      super(message)
    end

  end

end
