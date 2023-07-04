# frozen_string_literal: true

module VanillaIse
  # Object class for Profiles in ISE
  class Profile < Object
    # Return all Profiles
    # @param [Integer] page_size The number of items to return per page.
    # @param [Integer] page_limit The number of pages to return.
    # @return [Array<VanillaIse::Profile>] An array of Profiles.
    def self.all(page_size: 100, page_limit: Float::INFINITY)
      Base.make_api_call(
        '/config/profilerprofile',
        :get,
        page_size: page_size,
        page_limit: page_limit
      ).collect { |profile| new(profile) }
    end

    # Search for Profiles using supplied filters
    # @param [Array<String>] filters An array of filters to use in the search.
    # @param [Integer] page_size The number of items to return per page.
    # @param [Integer] page_limit The number of pages to return.
    # @param [Boolean] fetch Whether or not to fetch the full Profile details.
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
        page_limit: page_limit
      )
      if fetch
        Async do |task|
          response.each do |profile|
            task.async { results << find(profile['id']) }
          end
        end
      else
        response.each { |profile| results << new(profile['id']) }
      end
      results
    end

    # Find a singular Profile by ID.
    # @param [String] id The ID of the Profile to find.
    # @return [VanillaIse::Profile] The Profile.
    def self.find(id)
      new Base.make_api_call(
        "/config/profilerprofile/#{id}",
        :get
      )&.dig('ProfilerProfile')
    end
  end
end
