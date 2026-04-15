# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module BrandLogo
  module Strategies
    module Scraping
      # Finds all favicon candidates in a parsed HTML document.
      # Returns unfiltered icons — validation/selection is the strategy's responsibility.
      class IconFinder
        extend T::Sig

        FAVICON_SELECTORS = T.let([
          'link[rel~="icon"]',
          'link[rel~="shortcut"]',
          'link[rel~="apple-touch-icon"]',
          'link[rel~="mask-icon"]',
          'link[type="image/x-icon"]',
          'link[type="image/vnd.microsoft.icon"]',
          'link[type="image/png"]',
          'link[type="image/svg+xml"]'
        ].freeze, T::Array[String])

        sig do
          params(
            doc: ParsedDocument,
            base_url: String,
            dimensions_extractor: DimensionsExtractor,
            default_favicon_checker: DefaultFaviconChecker
          ).void
        end
        def initialize(doc:, base_url:, dimensions_extractor:, default_favicon_checker:)
          @doc                      = T.let(doc, ParsedDocument)
          @url_normalizer           = T.let(UrlNormalizer.new(base_url), UrlNormalizer)
          @dimensions_extractor     = T.let(dimensions_extractor, DimensionsExtractor)
          @default_favicon_checker  = T.let(default_favicon_checker, DefaultFaviconChecker)
        end

        # Returns all icons found in the document. Falls back to /favicon.ico if none.
        sig { returns(T::Array[Icon]) }
        def find
          icons = find_icons_from_selectors
          return icons unless icons.empty?

          BrandLogo::Logging.logger.debug('No icons found in HTML, checking default /favicon.ico')
          default_icon = @default_favicon_checker.check(@url_normalizer.default_favicon_url)
          default_icon ? [default_icon] : []
        end

        private

        sig { returns(T::Array[Icon]) }
        def find_icons_from_selectors
          FAVICON_SELECTORS.flat_map { |selector| process_selector(selector) }
        end

        sig { params(selector: String).returns(T::Array[Icon]) }
        def process_selector(selector)
          @doc.css(selector).filter_map { |link| build_icon_from_link(link) }
        end

        sig { params(link: T.untyped).returns(T.nilable(Icon)) }
        def build_icon_from_link(link)
          href = link['href']
          return nil unless href

          normalized_url = @url_normalizer.normalize(href)
          dimensions     = @dimensions_extractor.extract(link, normalized_url)
          format         = FormatExtractor.extract(link)

          BrandLogo::Logging.logger.debug("Found icon: url=#{normalized_url} format=#{format} dimensions=#{dimensions}")

          Icon.new(url: normalized_url, dimensions: dimensions, format: format)
        end
      end
    end
  end
end
