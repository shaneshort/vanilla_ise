# frozen_string_literal: true

module VanillaIse
  # A module for converting logical filters into the filter format that ISE Expects
  # @attr_reader [String] filter The filter to apply to the request.
  class Filter
    attr_accessor :filter

    # create a new filter
    # @param [String] filter The filter to apply to the request.
    # @return [VanillaIse::Filter]
    def initialize(filter = '')
      @filter = filter
      @filter.gsub!(/==/, 'EQ')
      @filter.gsub!(/!=/, 'NE')
      @filter.gsub!(/>/, 'GT')
      @filter.gsub!(/>/, 'LT')
      @filter.gsub!(/\s+/, '.')
    end

    # This method is used to parse a supplied array of filters.
    # @param [Array] filters The array of filters to parse.
    # @return [Hash] The parsed filters.
    def self.parse(filters = [])
      converted_filters = []
      filters.each do |filter|
        converted_filters << Filter.new(filter).filter
      end
      { filter: converted_filters }
    end
  end
end
