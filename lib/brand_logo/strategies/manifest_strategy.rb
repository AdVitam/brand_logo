# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'
require 'json'

module BrandLogo
  module Strategies
    # Fetches icons from the Web App Manifest (PWA manifest).
    # Modern progressive web apps store high-resolution icons (192x192, 512x512)
    # in a manifest.json or .webmanifest file linked from the HTML.
    #
    # Flow:
    #   1. Fetch HTML → find <link rel="manifest" href="...">
    #   2. Fetch manifest JSON
    #   3. Parse icons[] array → build Icons
    class ManifestStrategy < BaseStrategy
      extend T::Sig

      MIME_TO_FORMAT = T.let({
        'image/png'     => 'png',
        'image/svg+xml' => 'svg',
        'image/jpeg'    => 'jpg',
        'image/webp'    => 'webp',
        'image/gif'     => 'gif'
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
        manifest_url = find_manifest_url(domain)
        return [] unless manifest_url

        parse_manifest_icons(manifest_url)
      rescue StandardError => e
        BrandLogo::Logging.logger.error("ManifestStrategy error for #{domain}: #{e.message}")
        []
      end

      private

      # Finds the manifest URL from the HTML <link rel="manifest"> tag.
      sig { params(domain: String).returns(T.nilable(String)) }
      def find_manifest_url(domain)
        html = fetch_html(domain)
        return nil unless html

        doc  = @html_parser.parse(html)
        node = doc.at('link[rel="manifest"]')
        return nil unless node

        href = node['href']
        return nil unless href

        Scraping::UrlNormalizer.new("https://#{domain}").normalize(href)
      end

      sig { params(domain: String).returns(T.nilable(String)) }
      def fetch_html(domain)
        @http_client.get_body("https://#{domain}") ||
          @http_client.get_body("https://www.#{domain}")
      end

      # Downloads and parses the manifest JSON, returning icons.
      sig { params(manifest_url: String).returns(T::Array[Icon]) }
      def parse_manifest_icons(manifest_url)
        body = @http_client.get_body(manifest_url)
        return [] unless body

        data = JSON.parse(body)
        icons_data = data['icons']
        return [] unless icons_data.is_a?(Array)

        url_normalizer = Scraping::UrlNormalizer.new(manifest_url)

        icons_data.filter_map { |entry| build_icon_from_entry(entry, url_normalizer) }
      rescue JSON::ParserError => e
        BrandLogo::Logging.logger.warn("ManifestStrategy: invalid JSON at #{manifest_url}: #{e.message}")
        []
      end

      sig { params(entry: T.untyped, url_normalizer: Scraping::UrlNormalizer).returns(T.nilable(Icon)) }
      def build_icon_from_entry(entry, url_normalizer)
        return nil unless entry.is_a?(Hash)

        src = entry['src']
        return nil unless src.is_a?(String) && !src.empty?

        url        = url_normalizer.normalize(src)
        dimensions = parse_sizes(entry['sizes'])
        format     = format_from_entry(entry, url)

        BrandLogo::Logging.logger.debug("ManifestStrategy found icon: #{url} #{dimensions}")
        Icon.new(url: url, dimensions: dimensions, format: format)
      end

      # Parses a `sizes` entry like "192x192" or "any".
      sig { params(sizes: T.untyped).returns(T::Hash[Symbol, T.nilable(Integer)]) }
      def parse_sizes(sizes)
        return { width: nil, height: nil } unless sizes.is_a?(String)

        parts = sizes.downcase.split('x')
        return { width: nil, height: nil } unless parts.length == 2

        width, height = parts.map(&:to_i)
        return { width: nil, height: nil } unless width.positive? && height.positive?

        { width: width, height: height }
      end

      sig { params(entry: T.untyped, url: String).returns(String) }
      def format_from_entry(entry, url)
        mime = entry['type']
        return MIME_TO_FORMAT[mime] if mime.is_a?(String) && MIME_TO_FORMAT.key?(mime)

        ext = File.extname(URI.parse(url).path).delete('.').downcase
        ext.empty? ? 'png' : ext
      rescue URI::Error
        'png'
      end
    end
  end
end
