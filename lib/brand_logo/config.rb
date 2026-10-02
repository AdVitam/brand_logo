# frozen_string_literal: true
# typed: strict

require 'digest'

module BrandLogo
  Config = Data.define(
    :min_size, :max_size, :allow_svg, :prefer, :target_size, :color_scheme,
    :timeout, :deadline, :max_hops, :max_body_bytes, :user_agent, :concurrency,
    :block_private_ips, :external_fallbacks, :cache, :cache_ttl, :negative_cache_ttl
  ) do
    extend T::Sig

    sig do
      params(
        min_size: T.untyped,
        max_size: T.untyped,
        allow_svg: T::Boolean,
        prefer: Symbol,
        target_size: T.nilable(Integer),
        color_scheme: T.nilable(Symbol),
        timeout: Numeric,
        deadline: Numeric,
        max_hops: Integer,
        max_body_bytes: Integer,
        user_agent: String,
        concurrency: Integer,
        block_private_ips: T::Boolean,
        external_fallbacks: T::Array[Symbol],
        cache: T.untyped,
        cache_ttl: Integer,
        negative_cache_ttl: Integer
      ).void
    end
    def initialize(
      min_size: nil, max_size: nil, allow_svg: true, prefer: :square, target_size: nil, color_scheme: nil,
      timeout: 5, deadline: 15, max_hops: 5, max_body_bytes: 2_000_000, user_agent: Config::USER_AGENT,
      concurrency: 4, block_private_ips: true, external_fallbacks: Config::EXTERNAL_FALLBACKS, cache: Cache::Memory.new,
      cache_ttl: 86_400, negative_cache_ttl: 3_600
    )
      super(
        min_size: Dimensions.coerce(min_size), max_size: Dimensions.coerce(max_size), allow_svg: allow_svg,
        prefer: prefer, target_size: target_size, color_scheme: color_scheme, timeout: timeout,
        deadline: deadline, max_hops: max_hops, max_body_bytes: max_body_bytes, user_agent: user_agent,
        concurrency: concurrency, block_private_ips: block_private_ips,
        external_fallbacks: external_fallbacks.dup.freeze, cache: cache, cache_ttl: cache_ttl,
        negative_cache_ttl: negative_cache_ttl
      )
      validate!
    end

    # Data#with skips initialize before Ruby 3.3, which would bypass coercion and validation.
    sig { params(changes: T.untyped).returns(Config) }
    def with(**changes)
      self.class.new(**to_h, **changes)
    end

    # Identifies the settings that change which icon wins, so cached results never leak across them.
    sig { returns(String) }
    def cache_digest
      Digest::SHA256.hexdigest(
        [min_size, max_size, allow_svg, prefer, target_size, color_scheme, external_fallbacks,
         block_private_ips].inspect
      )[0, 12].to_s
    end

    private

    sig { void }
    def validate!
      validate_choices!
      validate_numbers!
      check(cache.nil? || (cache.respond_to?(:read) && cache.respond_to?(:write)), 'cache must respond to read/write')
      check(!(min_size && max_size) || T.must(max_size).at_least?(T.must(min_size)), 'max_size must be >= min_size')
    end

    sig { void }
    def validate_choices!
      check(Config::PREFERENCES.include?(prefer), "prefer must be one of #{Config::PREFERENCES}")
      check(color_scheme.nil? || Config::COLOR_SCHEMES.include?(color_scheme),
            "color_scheme must be nil or one of #{Config::COLOR_SCHEMES}")
      check((external_fallbacks - Config::EXTERNAL_FALLBACKS).empty?,
            "external_fallbacks must be within #{Config::EXTERNAL_FALLBACKS}")
    end

    sig { void }
    def validate_numbers!
      size = target_size
      check(size.nil? || size.positive?, 'target_size must be positive')
      %i[timeout deadline max_body_bytes concurrency].each do |key|
        check(public_send(key).positive?, "#{key} must be positive")
      end
      %i[max_hops cache_ttl negative_cache_ttl].each { |key| check(!public_send(key).negative?, "#{key} must be >= 0") }
    end

    sig { params(condition: T::Boolean, message: String).void }
    def check(condition, message)
      raise ValidationError, message unless condition
    end
  end

  # Reopened because constants defined inside a Data.define block would land on BrandLogo.
  class Config
    PREFERENCES = T.let(%i[square largest svg].freeze, T::Array[Symbol])
    COLOR_SCHEMES = T.let(%i[light dark].freeze, T::Array[Symbol])
    EXTERNAL_FALLBACKS = T.let(%i[google duckduckgo].freeze, T::Array[Symbol])
    USER_AGENT = T.let(
      'Mozilla/5.0 (compatible; BrandLogo/2; +https://github.com/AdVitam/brand_logo)',
      String
    )
  end
end
