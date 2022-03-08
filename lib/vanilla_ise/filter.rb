module VanillaIse
  class Filter
    attr_accessor :filter

    def initialize(filter = '')
      @filter = filter
      @filter.gsub!(/==/, 'EQ')
      @filter.gsub!(/!=/, 'NE')
      @filter.gsub!(/\>/, 'GT')
      @filter.gsub!(/\>/, 'LT')
      @filter.gsub!(/\s+/, '.')
    end

    def self.parse(filters = [])
      converted_filters = []
      filters.each do |filter|
        converted_filters << Filter.new(filter).filter
      end
      { filter: converted_filters }
    end

  end
end