# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module BrandLogo
  module Strategies
    # Fetches brand logos by scraping the target website's HTML.
    # Tries HTTPS (with and without www), then falls back to HTTP.
    # Delegates HTML fetching, parsing, and image analysis to injected dependencies.
    class ScrapingStrategy < BaseStrategy
      extend T::Sig

      sig do
        params(
          config: Config,
          http_client: HttpClient,
          html_parser: HtmlParser,
          image_analyzer: ImageAnalyzer
        ).void
      end
      def initialize(config:, http_client:, html_parser:, image_analyzer:)
        super(config: config)
        @http_client    = T.let(http_client, HttpClient)
        @html_parser    = T.let(html_parser, HtmlParser)
        @image_analyzer = T.let(image_analyzer, ImageAnalyzer)
      end

      sig { override.params(domain: String).returns(T::Array[Icon]) }
      def fetch_all(domain)
        html, base_url = fetch_html_with_base_url(domain)
        return [] unless html

        dimensions_extractor    = Scraping::DimensionsExtractor.new(image_analyzer: @image_analyzer)
        default_favicon_checker = Scraping::DefaultFaviconChecker.new(http_client: @http_client)

        finder = Scraping::IconFinder.new(
          doc: @html_parser.parse(html),
          base_url: base_url,
          dimensions_extractor: dimensions_extractor,
          default_favicon_checker: default_favicon_checker
        )
        finder.find
      rescue StandardError => e
        BrandLogo::Logging.logger.error("ScrapingStrategy error for #{domain}: #{e.message}")
        []
      end

      private

      # Returns [html_body, base_url] for the first responding URL candidate, or nil.
      sig { params(domain: String).returns(T.nilable([String, String])) }
      def fetch_html_with_base_url(domain)
        url_candidates(domain).each do |url|
          body = @http_client.get_body(url)
          next unless body

          BrandLogo::Logging.logger.debug("Fetched HTML from #{url}")
          return [body, url]
        end

        BrandLogo::Logging.logger.debug("Could not fetch HTML for #{domain}")
        nil
      end

      # Ordered list of URLs to try: HTTPS without www, HTTPS with www, HTTP fallback.
      sig { params(domain: String).returns(T::Array[String]) }
      def url_candidates(domain)
        [
          "https://#{domain}",
          "https://www.#{domain}",
          "http://#{domain}"
        ]
      end
    end
  end
end
