# frozen_string_literal: true
# typed: strict

module BrandLogo
  module Strategies
    class JsonLd
      extend T::Sig
      include Base

      ORGANIZATION_TYPES = T.let(%w[Organization Corporation NGO LocalBusiness Brand].freeze, T::Array[String])
      ORGANIZATION_SUFFIXES = T.let(%w[Organization Business Store Brand].freeze, T::Array[String])
      OWNER_KEYS = T.let(%w[publisher brand].freeze, T::Array[String])

      sig { override.returns(Symbol) }
      def stage
        :document
      end

      sig { override.params(context: Context).returns(T::Array[Icon]) }
      def call(context)
        page = context.page
        return [] unless page

        logos = []
        page.document.css('script[type="application/ld+json"]').each do |script|
          collect(LenientJson.parse(script.text), false, logos)
        rescue JSON::ParserError => e
          Logging.logger.warn("JsonLd: invalid JSON at #{page.url}: #{e.message}")
        end
        logos.filter_map { |logo| build(page, logo) }
      end

      private

      sig { params(node: T.untyped, owner: T::Boolean, logos: T::Array[T.untyped]).void }
      def collect(node, owner, logos)
        case node
        when ::Array
          node.each { |child| collect(child, owner, logos) }
        when ::Hash
          logos.concat(declared_logos(node)) if owner || organization?(node['@type'])
          node.each { |key, child| collect(child, OWNER_KEYS.include?(key), logos) }
        end
      end

      sig { params(node: T::Hash[String, T.untyped]).returns(T::Array[T.untyped]) }
      def declared_logos(node)
        declared = node['logo']
        declared.is_a?(::Array) ? declared : [declared].compact
      end

      sig { params(types: T.untyped).returns(T::Boolean) }
      def organization?(types)
        Array(types).any? do |type|
          name = type.to_s.split(%r{[/:#]}).last.to_s
          ORGANIZATION_TYPES.include?(name) || name.end_with?(*ORGANIZATION_SUFFIXES)
        end
      end

      sig { params(page: Page, logo: T.untyped).returns(T.nilable(Icon)) }
      def build(page, logo)
        declared = logo.is_a?(::Hash) ? (logo['url'] || logo['contentUrl']) : logo
        url = page.resolve(declared) if declared.is_a?(String)
        return nil unless url

        Icon.new(url: url, source: :json_ld, kind: :logo, format: format_of(logo, url), dimensions: dimensions(logo))
      end

      sig { params(logo: T.untyped, url: String).returns(T.nilable(Symbol)) }
      def format_of(logo, url)
        mime = logo['encodingFormat'] if logo.is_a?(::Hash)
        ImageFormat.from_mime(mime) || ImageFormat.from_url(url)
      end

      sig { params(logo: T.untyped).returns(Dimensions) }
      def dimensions(logo)
        return Dimensions.new unless logo.is_a?(::Hash)

        Dimensions.new(width: pixels(logo['width']), height: pixels(logo['height']))
      end

      sig { params(value: T.untyped).returns(T.nilable(Integer)) }
      def pixels(value)
        number = value.is_a?(Numeric) ? value.to_i : value.to_s[/\A\d+/]&.to_i
        number if number&.positive?
      end
    end
  end
end
