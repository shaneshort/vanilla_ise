# frozen_string_literal: true

module VanillaIse
  # This class is used to represent an endpoint in ISE.
  class Endpoint < Object
    # Get all endpoints from ISE.
    # @param [Integer] page_size The number of endpoints to return per page.
    # @param [Integer] page_limit The number of pages to return.
    # @return [Array<VanillaIse::Endpoint>] An array of endpoints.
    def self.all(page_size: 100, page_limit: Float::INFINITY)
      Base.make_api_call(
        '/config/endpoint',
        :get,
        page_size: page_size,
        page_limit: page_limit
      ).collect { |endpoint| new(endpoint) }
    end

    # Find a singular endpoint by MAC address.
    # @param [String] mac_address The MAC address of the endpoint to find.
    # @return [VanillaIse::Endpoint] The endpoint.
    # @raise [VanillaIse::NotFound] If no endpoint is found.
    def self.find_by_mac(mac_address)
      response = search(["mac == #{mac_address}"])&.first

      raise NotFound, 'No device Found' if response.nil?

      response
    end

    # Search for endpoints using supplied filters
    # @param [Array<String>] filters An array of filters to use in the search.
    # @param [Integer] page_size The number of endpoints to return per page.
    # @param [Integer] page_limit The number of pages to return.
    # @param [Boolean] fetch Whether or not to fetch the full endpoint details.
    # @return [Array<VanillaIse::Endpoint>] An array of endpoints.
    # @raise [ArgumentError] If no filters are provided.
    def self.search(filters, page_size: 100, page_limit: Float::INFINITY, fetch: true, filter_operator: 'or')
      raise ArgumentError, 'No filters provided' if filters.empty?

      Base.disable_rails_query_string_format
      params = Filter.parse(filters)
      params[:filtertype] = filter_operator

      response = Base.make_api_call('/config/endpoint', :get,
                                    query_params: params,
                                    page_size: page_size,
                                    page_limit: page_limit)

      fetch ? async_fetch(response) : response.collect { |endpoint| new(endpoint) }
    end

    # Find a singular endpoint by ID.
    # @param [String] id The ID of the endpoint to find.
    # @return [VanillaIse::Endpoint] The endpoint.
    # @raise [VanillaIse::NotFound] If no endpoint is found.
    def self.find(id)
      endpoint = Base.make_api_call(
        "/config/endpoint/#{id}",
        :get
      )&.dig('ERSEndPoint')
      raise NotFound, 'No endpoint found' if endpoint.nil?

      new endpoint
    end

    # Fetch a collection of endpoints asynchronously.
    # @param [Array<Hash>] endpoints An array of endpoint hashes.
    # @return [Array<VanillaIse::Endpoint>] An array of endpoints.
    def self.async_fetch(endpoints)
      results = []
      Async do |task|
        endpoints.each do |endpoint|
          task.async { results << find(endpoint['id']) }
        end
      end
      results
    end

    # Persist the endpoint to ISE.
    # @return [VanillaIse::Endpoint] The endpoint.
    # @raise [VanillaIse::InvalidResponse] If the response is unexpected
    def save
      if persisted?
        response = VanillaIse::Base.make_api_call("/config/endpoint/#{id}",
                                                  :put, body:
                                                    {
                                                      ERSEndPoint: transform_to_hash.reject { |k, _| k == :link }
                                                    })

        if response.code != 200
          raise VanillaIse::InvalidResponse.new(response,
                                                message: "Failed to save: #{response.inspect}")
        end

      else
        response = VanillaIse::Base.make_api_call('/config/endpoint',
                                                  :post, body:
                                                    {
                                                      ERSEndPoint: transform_to_hash.reject { |k, _| k == :link }
                                                    })
        unless response.code == 201
          raise VanillaIse::InvalidResponse.new(response,
                                                message: "Failed to create endpoint: #{response.inspect}")
        end

        self.id = response.headers['Location'].split('/').last
      end

      VanillaIse::Endpoint.find(id)
    end

    # Destroy the endpoint in ISE.
    # @return [Boolean] True if the endpoint was destroyed.
    # @raise [VanillaIse::InvalidRequest] If the endpoint has not been destroyed or an unexpected response is received.
    def destroy
      raise InvalidRequest, 'cannot destroy endpoint unless it has been saved' unless persisted?

      response = VanillaIse::Base.make_api_call("/config/endpoint/#{id}",
                                                :delete)

      return if response.code == 204

      raise VanillaIse::InvalidResponse.new(response,
                                            message: "Failed to destroy endpoint: #{response.inspect}")
    end
  end
end
