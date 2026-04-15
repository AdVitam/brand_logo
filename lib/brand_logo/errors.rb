# frozen_string_literal: true
# typed: strict

module BrandLogo
  class Error < StandardError; end
  class FetchError < Error; end
  class ParseError < Error; end
  class ValidationError < Error; end
  class NoIconFoundError < FetchError; end
end
