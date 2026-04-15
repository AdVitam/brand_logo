# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module BrandLogo
  module Strategies
    # Fetches icons from Open Graph and Twitter Card meta tags.
    # These tags often contain high-resolution images (e.g. 1200x630 og:image),
    # making them a useful source when `max_dimensions` is not constrained.
    #
    # Tried after ScrapingStrategy (which handles dedicated favicon links),
    # before the DuckDuckGo last-resort fallback.
    class MetaTagStrategy < BaseStrategy
      extend T::Sig

      META_SELECTORS = T.let([
        'meta[property="og:image"]',
        'meta[name="twitter:image"]',
        'meta[name="twitter:image:src"]'
      ].freeze, T::Array[String])

      MIME_TO_FORMAT = T.let({
        'image/png'     => 'png',
        'image/svg+xml' => 'svg',
        'image/jpeg'    => 'jpg',
        'image/webp'    => 'webp'
      }.freeze, T::Hash[String, String])

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

        doc             = @html_parser.parse(html)
        url_normalizer  = Scraping::UrlNormalizer.new(base_url)

        META_SELECTORS.filter_map { |selector| build_icon_from_selector(doc, selector, url_normalizer) }
      rescue StandardError => e
        BrandLogo::Logging.logger.error("MetaTagStrategy error for #{domain}: #{e.message}")
        []
      end

      private

      sig { params(doc: ParsedDocument, selector: String, url_normalizer: Scraping::UrlNormalizer).returns(T.nilable(Icon)) }
      def build_icon_from_selector(doc, selector, url_normalizer)
        node = doc.at(selector)
        return nil unless node

        content = node['content']
        return nil unless content && !content.strip.empty?

        url        = url_normalizer.normalize(content.strip)
        dimensions = @image_analyzer.dimensions(url)
        format     = extract_format_from_url(url)

        BrandLogo::Logging.logger.debug("MetaTagStrategy found: #{url} (#{selector})")
        Icon.new(url: url, dimensions: dimensions, format: format)
      end

      sig { params(domain: String).returns(T.nilable([String, String])) }
      def fetch_html_with_base_url(domain)
        ["https://#{domain}", "https://www.#{domain}"].each do |url|
          body = @http_client.get_body(url)
          return [body, url] if body
        end
        nil
      end

      sig { params(url: String).returns(String) }
      def extract_format_from_url(url)
        ext = File.extname(URI.parse(url).path).delete('.').downcase
        ext.empty? ? 'unknown' : ext
      rescue URI::Error
        'unknown'
      end
    end
  end
end
