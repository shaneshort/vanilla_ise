# frozen_string_literal: true
require 'async'
require 'async/queue'
require 'httparty'
require 'dry-configurable'
require 'json'

require_relative 'vanilla_ise/version'
require_relative 'vanilla_ise/exceptions'

module VanillaIse
  autoload :Object, 'vanilla_ise/object'
  autoload :Endpoint, 'vanilla_ise/endpoint'
  autoload :Filter, 'vanilla_ise/filter'

  extend Dry::Configurable

  setting :server_url
  setting :username
  setting :password
  setting :debug, default: false

  class Base
    include HTTParty

    # Because ISE is stupid.
    query_string_normalizer proc { |query|
      query.map do |key, value|
        [value].flatten.map {|v| "#{key}=#{v}"}.join('&')
      end.join('&')
    }

    # @private
    # Inner function, not to be called directly
    def self.make_api_call(endpoint_url, http_method,
                           body: {},
                           query_params: {},
                           page_limit: Float::INFINITY,
                           page_size: 20)
      options = {
        basic_auth: { username: VanillaIse.config.username, password: VanillaIse.config.password },
        headers: { 'Accept': 'application/json', },
        body: body.to_json
      }
      options[:query] = query_params unless query_params.empty?
      options[:base_uri] = VanillaIse.config.server_url
      options[:debug_output] = $stdout if VanillaIse.config.debug

      case http_method
      when :get
        options[:query] ||= {}
        options[:query]['size'] = page_size
        #options[:query] = URI.encode_www_form(options[:query])

        page_count = 1
        results = []
        response = send(http_method, endpoint_url, options)&.parsed_response
        if response&.dig('SearchResult')
          results.concat(response&.dig('SearchResult', 'resources'))
          while (page_count += 1) && (next_page = response&.dig('SearchResult', 'nextPage', 'href')) && page_count <= page_limit
            # Grab the url params and update our existing options hash with it
            options[:query].merge!(Hash[URI.decode_www_form(URI.parse(next_page).query)])

            response = send(http_method, endpoint_url, options)&.parsed_response
            results.concat(response&.dig('SearchResult', 'resources'))
          end
          results
        else
          response
        end
      when :post, :put, :delete
        response = send(http_method, endpoint_url, options)
        JSON.parse(response&.body)
      else
        raise 'Invalid HTTP Method. Only GET, POST, PUT and DELETE are supported.'
      end
    end

  end

end
