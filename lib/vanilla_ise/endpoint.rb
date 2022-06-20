module VanillaIse
  class Endpoint < Object
    def self.all(page_size: 100, page_limit: Float::INFINITY)
      Base.make_api_call(
        '/config/endpoint',
        :get,
        page_size: page_size,
        page_limit: page_limit,
      ).collect { |endpoint| new(endpoint) }
    end

    def self.find_by_mac(mac_address)
      response = search(["mac == #{mac_address}"])&.first

      raise ArgumentError, 'No device Found' if response.nil?

      response
    end

    def self.search(filters, page_size: 100, page_limit: Float::INFINITY, fetch: true)
      raise ArgumentError, 'No filters provided' if filters.empty?

      Base.disable_rails_query_string_format
      params = Filter.parse(filters)
      params[:filtertype] = 'or'

      response = Base.make_api_call('/config/endpoint', :get,
                                    query_params: params,
                                    page_size: page_size,
                                    page_limit: page_limit)
      results = fetch ? async_fetch(response) : response.collect { |endpoint| new(endpoint) }

      results
    end

    def self.find(id)
      new Base.make_api_call(
        "/config/endpoint/#{id}",
        :get,
      )&.dig('ERSEndPoint')
    end

    def self.async_fetch(endpoints)
      results = []
      Async do |task|
        endpoints.each do |endpoint|
          task.async { results << find(endpoint['id']) }
        end
      end
      results
    end

    def save
      if persisted?
        response = VanillaIse::Base.make_api_call("/config/endpoint/#{id}",
                                                  :put, body:
                                                    {
                                                      ERSEndPoint: to_h.reject { |k, _| k == :link }
                                                    })

        raise ArgumentError, "Failed to save endpoint: #{response.inspect}" unless response.code == 200
      else
        response = VanillaIse::Base.make_api_call('/config/endpoint',
                                                  :post, body:
                                                    {
                                                      ERSEndPoint: to_h.reject { |k, _| k == :link }
                                                    })
        raise ArgumentError, "Failed to create endpoint: #{response.inspect}" unless response.code == 201

        self.id = response.headers['Location'].split('/').last
      end

      VanillaIse::Endpoint.find(id)
    end

    def destroy
      raise ArgumentError, 'cannot destroy endpoint unless it has been saved' unless persisted?

      response = VanillaIse::Base.make_api_call("/config/endpoint/#{id}",
                                                :delete)

      raise ArgumentError, "Failed to destroy endpoint: #{response.inspect}" unless response.code == 204

    end
  end
end
