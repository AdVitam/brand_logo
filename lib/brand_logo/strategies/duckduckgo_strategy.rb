# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module BrandLogo
  module Strategies
    # Fetches brand logos from DuckDuckGo's public icon service.
    # Used as a last-resort fallback when scraping finds nothing.
    class DuckduckgoStrategy < BaseStrategy
      extend T::Sig

      DUCKDUCKGO_URL = T.let('https://icons.duckduckgo.com/ip3/%s.ico', String)

      sig do
        params(
          config: Config,
          http_client: HttpClient,
          image_analyzer: ImageAnalyzer
        ).void
      end
      def initialize(config:, http_client:, image_analyzer:)
        super(config: config)
        @http_client    = T.let(http_client, HttpClient)
        @image_analyzer = T.let(image_analyzer, ImageAnalyzer)
      end

      sig { override.params(domain: String).returns(T::Array[Icon]) }
      def fetch_all(domain)
        url = format(DUCKDUCKGO_URL, domain)
        return [] unless @http_client.head_success?(url)

        icon = Icon.new(
          url: url,
          dimensions: @image_analyzer.dimensions(url),
          format: 'ico'
        )
        [icon]
      rescue StandardError => e
        BrandLogo::Logging.logger.error("DuckduckgoStrategy error for #{domain}: #{e.message}")
        []
      end
    end
  end
end
