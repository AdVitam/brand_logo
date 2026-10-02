# frozen_string_literal: true
# typed: strict

module BrandLogo
  class Error < StandardError; end
  class ValidationError < Error; end
  class NoIconFoundError < Error; end
end
