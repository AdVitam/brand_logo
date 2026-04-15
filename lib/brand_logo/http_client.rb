# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'
require 'http'

module BrandLogo
  # Interface for HTTP operations used by strategies.
  # Decouples strategies from the HTTP gem, enabling injection of test doubles.
  module HttpClient
    extend T::Sig
    extend T::Helpers

    interface!

    # Fetches the body of a URL. Returns nil on any failure (network, non-2xx, timeout).
    sig { abstract.params(url: String).returns(T.nilable(String)) }
    def get_body(url); end

    # Returns true if a HEAD request to the URL succeeds (2xx). Returns false on any failure.
    sig { abstract.params(url: String).returns(T::Boolean) }
    def head_success?(url); end
  end

  # Concrete HTTP client using the `http` gem.
  # Centralizes timeout and redirect configuration previously hardcoded
  # across ScrapingStrategy, DuckduckgoStrategy, and UrlNormalizer.
  class RealHttpClient
    extend T::Sig
    include HttpClient

    sig { params(config: Config).void }
    def initialize(config)
      @timeout  = T.let(config.timeout, Integer)
      @max_hops = T.let(config.max_hops, Integer)
    end

    sig { override.params(url: String).returns(T.nilable(String)) }
    def get_body(url)
      response = HTTP
                 .timeout(connect: @timeout, read: @timeout, write: @timeout)
                 .follow(max_hops: @max_hops)
                 .get(url)
      response.status.success? ? response.body.to_s : nil
    rescue StandardError
      nil
    end

    sig { override.params(url: String).returns(T::Boolean) }
    def head_success?(url)
      response = HTTP
                 .timeout(connect: @timeout, read: @timeout, write: @timeout)
                 .head(url)
      response.status.success?
    rescue StandardError
      false
    end
  end
end
