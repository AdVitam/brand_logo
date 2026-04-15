# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module BrandLogo
  module Strategies
    module Scraping
      # Checks whether the conventional /favicon.ico path exists for a domain.
      # Extracted from UrlNormalizer to respect SRP: URL normalization ≠ HTTP verification.
      class DefaultFaviconChecker
        extend T::Sig

        sig { params(http_client: HttpClient).void }
        def initialize(http_client:)
          @http_client = T.let(http_client, HttpClient)
        end

        # Returns an Icon if the URL responds with 2xx, nil otherwise.
        sig { params(url: String).returns(T.nilable(Icon)) }
        def check(url)
          return nil unless @http_client.head_success?(url)

          Icon.new(
            url: url,
            dimensions: Config::DEFAULT_DIMENSIONS,
            format: 'ico'
          )
        end
      end
    end
  end
end
