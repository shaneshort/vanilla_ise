module VanillaIse
  class Endpoint < Object
    def self.all(page_size: 100, page_limit: Float::INFINITY)
      Base.make_api_call(
        '/config/endpoint',
        :get,
        page_size: page_size,
        page_limit: page_limit,
      ).collect { |endpoint| self.new(endpoint) }
    end

    def self.search(filters, page_size: 100, page_limit: Float::INFINITY, fetch: true)
      raise ArgumentError 'No filters provided' if filters.empty?
      Base.disable_rails_query_string_format
      params = Filter.parse(filters)
      params[:filtertype] = 'or'

      results = []

      response = Base.make_api_call(
        '/config/endpoint',
        :get,
        query_params: params,
        page_size: page_size,
        page_limit: page_limit,
      )
      if fetch
        Async do |task|
          response.each do |endpoint|
            task.async { results << self.find(endpoint['id']) }
          end
        end
      else
        response.each { |endpoint| results << new(endpoint['id']) }
      end
      results
    end

    def self.find(id)
      new Base.make_api_call(
        "/config/endpoint/#{id}",
        :get,
      )&.dig('ERSEndPoint')
    end
  end
end