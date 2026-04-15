# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module BrandLogo
  # Immutable configuration object for the gem.
  # Centralizes all runtime parameters, replacing the 4 primitive kwargs
  # previously duplicated across every strategy constructor.
  #
  # Usage:
  #   config = BrandLogo::Config.new(min_dimensions: { width: 32, height: 32 }, timeout: 5)
  class Config
    extend T::Sig

    DEFAULT_TIMEOUT      = T.let(10, Integer)
    DEFAULT_MAX_HOPS     = T.let(5, Integer)
    DEFAULT_MIN_DIMENSIONS = T.let({ width: 0, height: 0 }.freeze, T::Hash[Symbol, Integer])
    DEFAULT_DIMENSIONS   = T.let({ width: 16, height: 16 }.freeze, T::Hash[Symbol, Integer])
    DEFAULT_FAVICON_PATH = T.let('/favicon.ico', String)

    sig { returns(T::Hash[Symbol, Integer]) }
    attr_reader :min_dimensions

    sig { returns(T.nilable(T::Hash[Symbol, Integer])) }
    attr_reader :max_dimensions

    sig { returns(T::Boolean) }
    attr_reader :allow_svg

    sig { returns(Integer) }
    attr_reader :timeout

    sig { returns(Integer) }
    attr_reader :max_hops

    sig do
      params(
        min_dimensions: T::Hash[Symbol, Integer],
        max_dimensions: T.nilable(T::Hash[Symbol, Integer]),
        allow_svg: T::Boolean,
        timeout: Integer,
        max_hops: Integer
      ).void
    end
    def initialize(
      min_dimensions: DEFAULT_MIN_DIMENSIONS,
      max_dimensions: nil,
      allow_svg: true,
      timeout: DEFAULT_TIMEOUT,
      max_hops: DEFAULT_MAX_HOPS
    )
      @min_dimensions = T.let(min_dimensions, T::Hash[Symbol, Integer])
      @max_dimensions = T.let(max_dimensions, T.nilable(T::Hash[Symbol, Integer]))
      @allow_svg      = T.let(allow_svg, T::Boolean)
      @timeout        = T.let(timeout, Integer)
      @max_hops       = T.let(max_hops, Integer)
    end
  end
end
