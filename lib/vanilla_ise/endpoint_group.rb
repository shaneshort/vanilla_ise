# frozen_string_literal: true

module VanillaIse
  # This class is used to represent an endpoint group in Cisco ISE.
  class EndpointGroup < Object
    # Return all endpoint groups
    # @param [Integer] page_size The number of items to return per page.
    # @param [Integer] page_limit The number of pages to return.
    # @return [Array<VanillaIse::EndpointGroup>] An array of endpoint groups.
    def self.all(page_size: 100, page_limit: Float::INFINITY)
      Base.make_api_call(
        '/config/endpointgroup',
        :get,
        page_size: page_size,
        page_limit: page_limit
      ).collect { |group| new(group) }
    end

    # Search for endpoint groups using supplied filters
    # @param [Array<String>] filters An array of filters to use in the search.
    # @param [Integer] page_size The number of items to return per page.
    # @param [Integer] page_limit The number of pages to return.
    # @param [Boolean] fetch Whether or not to fetch the full endpoint group details.
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
        page_limit: page_limit
      )
      if fetch
        Async do |task|
          response.each do |group|
            task.async { results << find(group['id']) }
          end
        end
      else
        response.each { |group| results << new(group['id']) }
      end
      results
    end

    # Find a singular endpoint group by ID.
    # @param [String] id The ID of the endpoint group to find.
    # @return [VanillaIse::EndpointGroup] The endpoint group.
    def self.find(id)
      new Base.make_api_call(
        "/config/endpointgroup/#{id}",
        :get
      )&.dig('EndPointGroup')
    end
  end
end
