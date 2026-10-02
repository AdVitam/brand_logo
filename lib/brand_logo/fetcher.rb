# frozen_string_literal: true
# typed: strict

module BrandLogo
  class Fetcher
    extend T::Sig

    CACHE_NAMESPACE = 'brand_logo/v2'

    sig { returns(Config) }
    attr_reader :config

    sig do
      params(
        config: Config,
        http: T.nilable(Http::Client),
        strategies: T.nilable(T::Array[Strategies::Base])
      ).void
    end
    def initialize(config: Config.new, http: nil, strategies: nil)
      @config = config
      @http = T.let(http || Http::RealClient.new(config), Http::Client)
      @strategies = T.let(strategies || default_strategies, T::Array[Strategies::Base])
      @ranker = T.let(Ranker.new(config), Ranker)
      strategy_names = @strategies.map { |strategy| T.cast(strategy, Object).class.name }
      @cache_digest = T.let(Digest::SHA256.hexdigest([config.cache_digest, strategy_names].inspect)[0, 12].to_s, String)
    end

    sig { params(input: String).returns(T.nilable(Icon)) }
    def fetch(input)
      fetch_domain(Domain.normalize(input))
    end

    sig { params(input: String).returns(Icon) }
    def fetch!(input)
      fetch(input) || raise(NoIconFoundError, "No icon found for #{input.inspect}")
    end

    sig { params(input: String).returns(T::Array[Icon]) }
    def fetch_all(input)
      domain = Domain.normalize(input)
      stored = cached("all/#{domain}") do
        lookup = new_lookup(domain)
        icons = lookup.all
        [icons.map(&:to_h), ttl_for(found: !icons.empty?, lookup: lookup)]
      end
      Array(stored).map { |hash| Icon.from_h(hash) }
    end

    sig { params(inputs: T::Array[String]).returns(T::Hash[String, T.nilable(Icon)]) }
    def fetch_many(inputs)
      domains = inputs.to_h { |input| [input, Domain.normalize(input)] }
      unique = domains.values.uniq
      icons = unique.zip(Concurrency.map(unique, size: @config.concurrency) { |domain| fetch_domain(domain) }).to_h
      domains.transform_values { |domain| icons[domain] }
    end

    private

    sig { params(domain: String).returns(T.nilable(Icon)) }
    def fetch_domain(domain)
      stored = cached("best/#{domain}") do
        lookup = new_lookup(domain)
        icon = lookup.best
        [icon ? icon.to_h : false, ttl_for(found: !icon.nil?, lookup: lookup)]
      end
      stored ? Icon.from_h(stored) : nil
    end

    sig { params(key: String, block: T.proc.returns([T.untyped, T.nilable(Integer)])).returns(T.untyped) }
    def cached(key, &block)
      cache = @config.cache
      return yield.first unless cache

      full_key = "#{CACHE_NAMESPACE}/#{key}/#{@cache_digest}"
      stored = cache.read(full_key)
      return stored unless stored.nil?

      value, ttl = yield
      cache.write(full_key, value, expires_in: ttl) if ttl&.positive?
      value
    end

    # A lookup cut short by the deadline says little about the site, so it is never cached.
    sig { params(found: T::Boolean, lookup: Lookup).returns(T.nilable(Integer)) }
    def ttl_for(found:, lookup:)
      return nil if lookup.timed_out?

      found ? @config.cache_ttl : @config.negative_cache_ttl
    end

    sig { params(domain: String).returns(Lookup) }
    def new_lookup(domain)
      context = Context.new(domain: domain, config: @config, http: @http)
      Lookup.new(context: context, strategies: @strategies, ranker: @ranker)
    end

    sig { returns(T::Array[Strategies::Base]) }
    def default_strategies
      document = [Strategies::LinkTag.new, Strategies::JsonLd.new, Strategies::MetaTag.new]
      remote = [Strategies::Manifest.new, Strategies::Browserconfig.new]
      external = { google: Strategies::Google, duckduckgo: Strategies::Duckduckgo }
      document + remote + @config.external_fallbacks.map { |name| external.fetch(name).new }
    end
  end
end
