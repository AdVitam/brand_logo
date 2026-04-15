# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module BrandLogo
  # Entry point for brand_logo retrieval.
  #
  # Composes a chain of strategies tried in order until one finds a valid icon.
  # Dependencies (HTTP client, HTML parser, image analyzer) are instantiated once
  # and shared across all strategies.
  #
  # Usage:
  #   # Default configuration
  #   icon = BrandLogo::Fetcher.new.fetch('github.com')
  #
  #   # Custom config
  #   config = BrandLogo::Config.new(min_dimensions: { width: 32, height: 32 }, timeout: 5)
  #   icon = BrandLogo::Fetcher.new(config: config).fetch('github.com')
  #
  #   # Custom strategy chain (OCP)
  #   fetcher = BrandLogo::Fetcher.new(strategies: [MyCustomStrategy.new(config: config)])
  #
  #   # All icons from all strategies
  #   icons = BrandLogo::Fetcher.new.fetch_all('github.com')
  class Fetcher
    extend T::Sig

    DOMAIN_PATTERN = T.let(/\A[a-z0-9\-.]+\.[a-z]{2,}\z/i, Regexp)

    sig do
      params(
        config: T.nilable(Config),
        strategies: T.nilable(T::Array[Strategies::BaseStrategy])
      ).void
    end
    def initialize(config: nil, strategies: nil)
      @config         = T.let(config || Config.new, Config)
      @http_client    = T.let(RealHttpClient.new(@config), HttpClient)
      @image_analyzer = T.let(FastimageAnalyzer.new, ImageAnalyzer)
      @html_parser    = T.let(NokogiriParser.new, HtmlParser)
      @strategies     = T.let(strategies || build_default_strategies, T::Array[Strategies::BaseStrategy])
    end

    # Returns the best icon found for the domain across all strategies.
    # Raises NoIconFoundError if no strategy finds a valid icon.
    sig { params(domain: String).returns(Icon) }
    def fetch(domain)
      validate_domain!(domain)
      BrandLogo::Logging.logger.debug("Fetching brand_logo for: #{domain}")

      @strategies.each do |strategy|
        BrandLogo::Logging.logger.debug("Trying #{strategy.class.name}")
        icon = strategy.fetch(domain)
        return icon if icon
      end

      raise NoIconFoundError, "No brand_logo found for #{domain}"
    end

    # Returns all icons found across every strategy, deduplicated by URL.
    sig { params(domain: String).returns(T::Array[Icon]) }
    def fetch_all(domain)
      validate_domain!(domain)

      @strategies
        .flat_map { |strategy| strategy.fetch_all(domain) }
        .uniq(&:url)
    end

    private

    sig { params(domain: String).void }
    def validate_domain!(domain)
      return if domain.match?(DOMAIN_PATTERN)

      raise ValidationError, "Invalid domain: #{domain.inspect}"
    end

    sig { returns(T::Array[Strategies::BaseStrategy]) }
    def build_default_strategies
      [
        Strategies::ScrapingStrategy.new(
          config: @config,
          http_client: @http_client,
          html_parser: @html_parser,
          image_analyzer: @image_analyzer
        ),
        Strategies::MetaTagStrategy.new(
          config: @config,
          http_client: @http_client,
          html_parser: @html_parser,
          image_analyzer: @image_analyzer
        ),
        Strategies::ManifestStrategy.new(
          config: @config,
          http_client: @http_client,
          html_parser: @html_parser,
          image_analyzer: @image_analyzer
        ),
        Strategies::DuckduckgoStrategy.new(
          config: @config,
          http_client: @http_client,
          image_analyzer: @image_analyzer
        )
      ]
    end
  end
end
