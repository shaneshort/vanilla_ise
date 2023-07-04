# frozen_string_literal: true

module VanillaIse
  class Error < StandardError; end

  class CSRFRequired < Error; end

  class CSRFTokenExpired < Error; end

  class NotFound < Error; end

  class InvalidRequest < Error; end

  class InvalidResponse < Error
    attr_reader :parsed_response

    def initialize(response, message: "An unknown error was encountered when submitting the data to Cisco ISE. Please try again.")
      @parsed_response = response&.parsed_response
      super(message)
    end

  end

end
end
