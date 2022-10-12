# frozen_string_literal: true

module VanillaIse
  class Error < StandardError; end
  class CSRFRequired < Error; end
  class CSRFTokenExpired < Error; end
end
