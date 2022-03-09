module VanillaIse
  class EndpointGroup < Object
    def self.all(page_size: 100, page_limit: Float::INFINITY)
      Base.make_api_call(
        '/config/endpointgroup',
        :get,
        page_size: page_size,
        page_limit: page_limit,
        ).collect { |group| self.new(group) }
    end

    def self.search(filters, page_size: 100, page_limit: Float::INFINITY, fetch: true)
      raise ArgumentError 'No filters provided' if filters.empty?
      Base.disable_rails_query_string_format
      params = Filter.parse(filters)
      params[:filtertype] = 'or'

      results = []

      response = Base.make_api_call(
        '/config/endpointgroup',
        :get,
        query_params: params,
        page_size: page_size,
        page_limit: page_limit,
        )
      if fetch
        Async do |task|
          response.each do |group|
            task.async { results << self.find(group['id']) }
          end
        end
      else
        response.each { |group| results << new(group['id']) }
      end
      results
    end

    def self.find(id)
      new Base.make_api_call(
        "/config/endpointgroup/#{id}",
        :get,
        )&.dig('EndPointGroup')
    end
  end
end