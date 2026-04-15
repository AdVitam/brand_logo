# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module BrandLogo
  module Strategies
    module Scraping
      # Extracts pixel dimensions from a favicon link element.
      # Tries the HTML `sizes` attribute first (no network), then falls back
      # to the injected ImageAnalyzer (may make a network request).
      class DimensionsExtractor
        extend T::Sig

        sig { params(image_analyzer: ImageAnalyzer).void }
        def initialize(image_analyzer:)
          @image_analyzer = T.let(image_analyzer, ImageAnalyzer)
        end

        # Returns dimensions for the given link element and its resolved href.
        sig { params(link: T.untyped, href: String).returns(T::Hash[Symbol, T.nilable(Integer)]) }
        def extract(link, href)
          extract_from_sizes_attribute(link) || @image_analyzer.dimensions(href)
        end

        private

        # Parses the `sizes` HTML attribute (e.g. "32x32") without a network call.
        sig { params(link: T.untyped).returns(T.nilable(T::Hash[Symbol, T.nilable(Integer)])) }
        def extract_from_sizes_attribute(link)
          sizes = link['sizes']&.split('x')
          return nil unless sizes&.length == 2

          width, height = T.cast(sizes, T::Array[String]).map(&:to_i)
          return nil unless width.positive? && height.positive?

          { width: width, height: height }
        end
      end
    end
  end
end
