# frozen_string_literal: true
require 'async'
require 'async/queue'
require 'httparty'
require 'dry-configurable'
require 'json'
require 'connection_pool'

require_relative 'vanilla_ise/version'
require_relative 'vanilla_ise/exceptions'

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

      self.client = VanillaIse::ConnectionWrapper.new(size: VanillaIse.config.concurrency_limit, timeout: 15) {
        VanillaIse::Base
      }
    end
  end

  class Base
    include HTTParty

    class << self
      attr_accessor :client
      attr_accessor :cookies
      attr_accessor :csrf_token
    end

    # @private
    # Do the HTTP Request
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

      if http_method == :get && !VanillaIse.config.read_only_url.nil?
        options[:base_uri] = VanillaIse.config.read_only_url
      end

      case http_method
      when :get
        # noop
      when :post, :put, :delete
        options[:headers]['X-CSRF-Token'] = VanillaIse::CsrfToken.request_token if VanillaIse.config.csrf_enabled
        options[:headers]['Content-Type'] = 'application/json' unless http_method == :delete
      else
        raise UnsupportedFormat, "Unsupported HTTP method: #{http_method}"
      end

      api_response = VanillaIse.client.with_retry(limit: 5) do |client|
        client.send(http_method, endpoint_url, options)
      end

      if api_response.code == 403 && api_response.body.include?('CSRF')
        raise VanillaIse::CSRFRequired, 'CSRF is required but not enabled' unless VanillaIse.config.csrf_enabled

        options[:headers]['X-CSRF-Token'] = VanillaIse::CsrfToken.force_refresh
        api_response = VanillaIse.client.with_retry(limit: 5) do |client|
          client.send(http_method, endpoint_url, options)
        end
      end

      # initialise the cookie jar if it's currently empty
      self.cookies ||= HTTParty::CookieHash.new
      # if we've been given cookies back in the request, store them
      api_response.get_fields('Set-Cookie')&.each { |c| self.cookies.add_cookies(c) }

      api_response
    end

    # @private
    # Inner function, not to be called directly
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

        page_count = 1
        results = []

        response = dispatch_request(endpoint_url, http_method,
                                    body: body, query_params: query_params, headers: headers)&.parsed_response

        if response&.dig('SearchResult')
          results.concat(response&.dig('SearchResult', 'resources'))
          while (page_count += 1) && (next_page = response&.dig('SearchResult', 'nextPage', 'href')) && page_count <= page_limit
            # Grab the url params and update our existing options hash with it
            query_params.merge!(Hash[URI.decode_www_form(URI.parse(next_page).query)])
            response = dispatch_request(endpoint_url, http_method, body: body, query_params: query_params, headers: headers)

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

  end

end
