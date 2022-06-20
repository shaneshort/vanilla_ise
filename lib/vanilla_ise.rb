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
  setting :concurrency_limit, default: 10

  class << self
    attr_accessor :client

    def configure!
      self.client = VanillaIse::ConnectionWrapper.new(size: VanillaIse.config.concurrency_limit, timeout: 15) {
        VanillaIse::Base
      }
    end
  end

  class Base
    include HTTParty

    class << self
      attr_accessor :client
    end

    # @private
    # Inner function, not to be called directly
    def self.make_api_call(endpoint_url, http_method,
                           body: nil,
                           query_params: {},
                           page_limit: Float::INFINITY,
                           page_size: 20)
      options = {
        basic_auth: { username: VanillaIse.config.username, password: VanillaIse.config.password },
        headers: { 'Accept': 'application/json' },
        base_uri: VanillaIse.config.server_url
      }
      options[:query] = query_params unless query_params.empty?
      options[:debug_output] = $stdout if VanillaIse.config.debug
      options[:body] = body.to_json if body

      if http_method == :get && !VanillaIse.config.read_only_url.nil?
        options[:base_uri] = VanillaIse.config.read_only_url
      end

      VanillaIse.configure! if VanillaIse.client.nil?
      case http_method
      when :get
        options[:query] ||= {}
        options[:query]['size'] = page_size

        page_count = 1
        results = []

        begin
          response = VanillaIse.client.with_retry(limit: 5) { |client| client.send(http_method, endpoint_url, options)&.parsed_response }
        rescue ConnectionPool::TimeoutError
          retry
        end

        if response&.dig('SearchResult')
          results.concat(response&.dig('SearchResult', 'resources'))
          while (page_count += 1) && (next_page = response&.dig('SearchResult', 'nextPage', 'href')) && page_count <= page_limit
            # Grab the url params and update our existing options hash with it
            options[:query].merge!(Hash[URI.decode_www_form(URI.parse(next_page).query)])
            response = VanillaIse.client.with_retry { |client| client.send(http_method, endpoint_url, options)&.parsed_response }

            results.concat(response&.dig('SearchResult', 'resources'))
          end
          results
        else
          response
        end
      when :post, :put, :delete
        options[:headers]['Content-Type'] = 'application/json' unless http_method == :delete
        response = VanillaIse.client.with_retry { |client| client.send(http_method, endpoint_url, options) }

        response
      else
        raise 'Invalid HTTP Method. Only GET, POST, PUT and DELETE are supported.'
      end
    end

  end

end
