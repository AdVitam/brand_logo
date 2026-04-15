# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module BrandLogo
  module Strategies
    module Scraping
      # Resolves favicon href values into absolute URLs.
      # Pure string manipulation — no network calls (SRP).
      # HTTP verification of the default favicon is handled by DefaultFaviconChecker.
      class UrlNormalizer
        extend T::Sig

        sig { params(base_url: String).void }
        def initialize(base_url)
          @base_url = T.let(base_url, String)
        end

        # Returns an absolute URL, resolving relative hrefs against the base URL.
        sig { params(href: String).returns(String) }
        def normalize(href)
          return href if absolute_url?(href)

          join_with_base_url(href)
        end

        # Returns the conventional favicon path for the domain.
        sig { returns(String) }
        def default_favicon_url
          "#{@base_url}#{Config::DEFAULT_FAVICON_PATH}"
        end

        private

        sig { params(href: String).returns(T::Boolean) }
        def absolute_url?(href)
          href.start_with?('http://', 'https://')
        end

        sig { params(href: String).returns(String) }
        def join_with_base_url(href)
          URI.join(@base_url, href).to_s
        rescue URI::Error
          href
        end
      end
    end
  end
end
