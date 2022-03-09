module VanillaIse
  class Profile < Object
    def self.all(page_size: 100, page_limit: Float::INFINITY)
      Base.make_api_call(
        '/config/profilerprofile',
        :get,
        page_size: page_size,
        page_limit: page_limit,
        ).collect { |profile| self.new(profile) }
    end

    def self.search(filters, page_size: 100, page_limit: Float::INFINITY, fetch: true)
      raise ArgumentError 'No filters provided' if filters.empty?
      Base.disable_rails_query_string_format
      params = Filter.parse(filters)
      params[:filtertype] = 'or'

      results = []

      response = Base.make_api_call(
        '/config/profilerprofile',
        :get,
        query_params: params,
        page_size: page_size,
        page_limit: page_limit,
        )
      if fetch
        Async do |task|
          response.each do |profile|
            task.async { results << self.find(profile['id']) }
          end
        end
      else
        response.each { |profile| results << new(profile['id']) }
      end
      results
    end

    def self.find(id)
      new Base.make_api_call(
        "/config/profilerprofile/#{id}",
        :get,
        )&.dig('ProfilerProfile')
    end
  end
end