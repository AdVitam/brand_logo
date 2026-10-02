# frozen_string_literal: true
# typed: strict

module BrandLogo
  module Strategies
    class LinkTag
      extend T::Sig
      include Base

      APPLE_TOUCH = T.let(%w[apple-touch-icon apple-touch-icon-precomposed].freeze, T::Array[String])

      sig { override.returns(Symbol) }
      def stage
        :document
      end

      sig { override.params(context: Context).returns(T::Array[Icon]) }
      def call(context)
        page = context.page
        return [] unless page

        page.document.css('link[rel]').filter_map { |link| build(page, link) } << favicon(page)
      end

      private

      sig { params(page: Page, link: Nokogiri::XML::Element).returns(T.nilable(Icon)) }
      def build(page, link)
        kind = kind_of(link['rel'].to_s.downcase.split)
        url = page.resolve(link['href'])
        return nil unless kind && url

        Icon.new(
          url: url,
          source: :link_tag,
          kind: kind,
          format: ImageFormat.from_mime(link['type']) || ImageFormat.from_url(url),
          dimensions: Dimensions.parse(link['sizes']),
          media: link['media']
        )
      end

      sig { params(tokens: T::Array[String]).returns(T.nilable(Symbol)) }
      def kind_of(tokens)
        if tokens.include?('mask-icon') then :mask
        elsif tokens.intersect?(APPLE_TOUCH) then :apple_touch
        elsif tokens.include?('icon') then :icon
        end
      end

      sig { params(page: Page).returns(Icon) }
      def favicon(page)
        url = T.must(UrlResolver.resolve('/favicon.ico', page.url))
        Icon.new(url: url, source: :link_tag, format: :ico)
      end
    end
  end
end
