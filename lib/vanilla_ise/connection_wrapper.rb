# frozen_string_literal: true

module VanillaIse
  # This class is used to wrap the connection pool and add a retry mechanism.
  # @param [Integer] limit The number of times to retry the connection.
  # @param [Block] block The block to execute.
  # @return [VanillaIse::ConnectionWrapper]
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
