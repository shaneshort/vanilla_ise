# frozen_string_literal: true

module VanillaIse
  class ConnectionWrapper < ConnectionPool
    def with_retry(limit: 1, &block)
      retries = 0
      begin
        with(&block)
      rescue ConnectionPool::TimeoutError
        raise if retries >= limit

        retries += 1
        retry
      end
    end
  end
end
