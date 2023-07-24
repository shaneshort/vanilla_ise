# frozen_string_literal: true

module VanillaIse
  # This class handles the CSRF token for the API.
  class CsrfToken
    class << self
      attr_accessor :token, :expiry

      # This method is used to force a refresh of the CSRF token.
      # @return [String] The CSRF token.
      def force_refresh
        self.expiry = nil
        refresh!(force: true)
        token
      end

      # This method is used to request a CSRF token.
      # @return [String] The CSRF token.
      def request_token
        refresh!
        token
      end

      # This method is used to refresh the CSRF token.
      # @param [Boolean] force Whether to force a refresh of the CSRF token.
      # @return [String] The CSRF token.
      def refresh!(force: false)
        return token unless force || expired?

        api_response = VanillaIse::Base.dispatch_request('/config/sgt/versioninfo', :get,
                                                         headers: { 'X-CSRF-TOKEN' => 'fetch' })

        # if we have a CSRF token in the request, store that too.
        self.token = api_response.get_fields('X-CSRF-Token')&.first
        self.expiry = Time.now.to_i + 60

        token
      end

      # This method is used to determine if the CSRF token has expired.
      # @return [Boolean] Whether the CSRF token has expired.
      def expired?
        return true if expiry.nil?

        Time.now.to_i > expiry
      end
    end
  end
end
