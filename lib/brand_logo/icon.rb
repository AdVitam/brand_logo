# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module BrandLogo
  # Represents a brand_logo icon with its URL, dimensions and format
  # Used to store and return brand_logo information across the gem
  class Icon
    extend T::Sig

    sig { returns(String) }
    attr_reader :url

    sig { returns(T::Hash[Symbol, T.nilable(Integer)]) }
    attr_reader :dimensions

    sig { returns(String) }
    attr_reader :format

    sig do
      params(
        url: String,
        dimensions: T::Hash[Symbol, T.nilable(Integer)],
        format: String
      ).void
    end
    def initialize(url:, dimensions:, format:)
      @url = url
      @dimensions = dimensions
      @format = format
    end
  end
end
