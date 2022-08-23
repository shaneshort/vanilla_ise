module VanillaIse
  class CsrfToken
    class << self

      attr_accessor :token
      attr_accessor :expiry

      def force_refresh
        self.expiry = nil
        refresh!(force: true)
        token
      end

      def request_token
        refresh!
        token
      end

      def refresh!(force: false)
        return token unless force || expired?

        api_response = VanillaIse::Base.dispatch_request('/config/sgt/versioninfo', :get,
                                                         headers: { 'X-CSRF-TOKEN' => 'fetch' })

        # if we have a CSRF token in the request, store that too.
        self.token = api_response.get_fields('X-CSRF-Token')&.first
        self.expiry = Time.now.to_i + 60

        token
      end

      def expired?
        return true if expiry.nil?

        Time.now.to_i > expiry
      end
    end
  end
end