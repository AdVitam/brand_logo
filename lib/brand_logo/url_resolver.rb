# frozen_string_literal: true
# typed: strict

require 'uri'

module BrandLogo
  module UrlResolver
    extend T::Sig

    DATA_IMAGE = %r{\Adata:image/}i

    sig { params(href: T.nilable(String), base: String).returns(T.nilable(String)) }
    def self.resolve(href, base)
      value = href.to_s.strip
      return nil if value.empty?
      return value if value.match?(DATA_IMAGE)

      uri = join(base, value) || join(base, URI::DEFAULT_PARSER.escape(value))
      uri.to_s if uri.is_a?(URI::HTTP) && uri.host
    end

    sig { params(base: String, value: String).returns(T.nilable(URI::Generic)) }
    def self.join(base, value)
      URI.join(base, value)
    rescue URI::Error
      nil
    end
    private_class_method :join
  end
end
