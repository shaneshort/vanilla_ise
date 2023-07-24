# frozen_string_literal: true

require 'async'
require 'async/queue'
require 'httparty'
require 'dry-configurable'
require 'json'
require 'connection_pool'

require_relative 'vanilla_ise/version'
require_relative 'vanilla_ise/exceptions'

# This is the main module for the gem. It is used to configure the gem and
# provides the main interface for the gem.
module VanillaIse
  autoload :CsrfToken, 'vanilla_ise/csrf_token'
  autoload :Object, 'vanilla_ise/object'
  autoload :Endpoint, 'vanilla_ise/endpoint'
  autoload :Filter, 'vanilla_ise/filter'
  autoload :Profile, 'vanilla_ise/profile'
  autoload :EndpointGroup, 'vanilla_ise/endpoint_group'
  autoload :ConnectionWrapper, 'vanilla_ise/connection_wrapper'

  extend Dry::Configurable

  setting :server_url
  setting :read_only_url, default: nil
  setting :username
  setting :password
  setting :debug, default: false
  setting :csrf_enabled, default: true
  setting :concurrency_limit, default: 10

  class << self
    attr_accessor :client

    def configured?
      !VanillaIse.config.server_url.nil? && \
        !VanillaIse.config.username.nil? && \
        !VanillaIse.config.password.nil?
    end

    def configure!
      raise 'required arguments [server_url, username, password] are not present' unless configured?

      self.client = VanillaIse::ConnectionWrapper.new(size: VanillaIse.config.concurrency_limit, timeout: 15) do
        VanillaIse::Base
      end
    end
  end

  # This is the base class for all API classes. It provides the basic HTTP methods and settings
  class Base
    include HTTParty

    class << self
      attr_accessor :client, :cookies, :csrf_token
    end

    # @private
    # Do the HTTP Request
    # @param [String] endpoint_url The URL to send the request to.
    # @param [Symbol] http_method The HTTP method to use.
    # @param [Hash] body The body of the request.
    # @param [Hash] query_params The query parameters for the request.
    # @param [Hash] headers The headers for the request.
    # @return [HTTParty::Response] The response from the API.
    def self.dispatch_request(endpoint_url, http_method,
                              body: nil,
                              query_params: {},
                              headers: {})
      VanillaIse.configure! if VanillaIse.client.nil?

      options = {
        basic_auth: { username: VanillaIse.config.username, password: VanillaIse.config.password },
        headers: { 'Accept': 'application/json' }.merge(headers),
        base_uri: VanillaIse.config.server_url
      }

      options[:query] = query_params unless query_params.empty?
      options[:debug_output] = $stdout if VanillaIse.config.debug
      options[:body] = body.to_json if body
      options[:headers]['Cookie'] = cookies.to_cookie_string unless cookies.nil?

      case http_method
      when :get
        options[:base_uri] = VanillaIse.config.read_only_url unless VanillaIse.config.read_only_url.nil?
        # noop
      when :post, :put, :delete
        options[:headers]['X-CSRF-Token'] = VanillaIse::CsrfToken.request_token if VanillaIse.config.csrf_enabled
        options[:headers]['Content-Type'] = 'application/json' unless http_method == :delete
      else
        raise UnsupportedFormat, "Unsupported HTTP method: #{http_method}"
      end

      api_response = dispatch_retryable_request(http_method, endpoint_url, options)

      # initialise the cookie jar if it's currently empty
      self.cookies ||= HTTParty::CookieHash.new
      # if we've been given cookies back in the request, store them
      api_response.get_fields('Set-Cookie')&.each { |c| self.cookies.add_cookies(c) }

      api_response
    end

    # @private
    # Action the http request and handle any retry logic
    # @param [Symbol] http_method The HTTP method to use
    # @param [String] endpoint_url The URL to call
    # @param [Hash] options The options to use
    # @return [HTTParty::Response] The response from the API
    def self.dispatch_retryable_request(http_method, endpoint_url, options = {})
      retry_count ||= 0
      api_response = VanillaIse.client.with_retry(limit: 5) { |client| client.send(http_method, endpoint_url, options) }
      raise VanillaIse::CSRFTokenExpired if api_response.code == 403 && api_response.body.include?('CSRF')

      api_response
    rescue VanillaIse::CSRFTokenExpired
      raise VanillaIse::CSRFRequired, 'CSRF is required but not enabled' unless VanillaIse.config.csrf_enabled

      options[:headers]['X-CSRF-Token'] = VanillaIse::CsrfToken.force_refresh
      retry_count += 1
      retry_count >= 1 ? retry : raise
    end

    # @private
    # Inner function, not to be called directly
    # @param [String] endpoint_url The URL to call
    # @param [Symbol] http_method The HTTP method to use
    # @param [Hash] body The body of the request
    # @param [Hash] query_params The query parameters to use
    # @param [Integer] page_limit The maximum number of pages to return
    # @param [Integer] page_size The number of results to return per page
    # @param [Hash] headers The headers to use
    # @return [Hash,Array] The results of the API call
    def self.make_api_call(endpoint_url, http_method,
                           body: nil,
                           query_params: {},
                           page_limit: Float::INFINITY,
                           page_size: 20,
                           headers: {})
      query_params ||= {}
      headers ||= {}

      case http_method
      when :get
        query_params['size'] = page_size
        response = dispatch_request(endpoint_url, http_method,
                                    body: body,
                                    query_params: query_params,
                                    headers: headers)&.parsed_response

        if response&.dig('SearchResult')
          results = []
          page_count = 1

          results.concat(response&.dig('SearchResult', 'resources'))
          while (page_count += 1) && !response&.dig('SearchResult', 'nextPage', 'href').nil? && page_count <= page_limit
            query_params.merge!(extract_query_params(response))
            response = dispatch_request(endpoint_url,
                                        http_method,
                                        body: body,
                                        query_params: query_params,
                                        headers: headers)

            results.concat(response&.dig('SearchResult', 'resources'))
          end
          results
        else
          response
        end
      when :post, :put, :delete
        dispatch_request(endpoint_url, http_method, body: body, query_params: query_params, headers: headers)
      else
        raise UnsupportedFormat, 'Invalid HTTP Method. Only GET, POST, PUT and DELETE are supported.'
      end
    end

    def extract_query_params(response)
      next_page = response&.dig('SearchResult', 'nextPage', 'href')
      query_strings = URI.parse(next_page).query
      if query_strings.nil?
        raise InvalidResponse(response, message: 'Next page reference was returned but unable to be parsed')
      end

      next_page_params = URI.decode_www_form(query_strings)
      # Grab the url params and update our existing options hash with it
      Hash[next_page_params]
    end
  end
end
