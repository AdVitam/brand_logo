# frozen_string_literal: true
# typed: strict

module BrandLogo
  module Strategies
    class MetaTag
      extend T::Sig
      include Base

      KINDS = T.let({
        'og:image' => :social,
        'og:image:secure_url' => :social,
        'og:image:url' => :social,
        'twitter:image' => :social,
        'twitter:image:src' => :social,
        'og:logo' => :logo,
        'msapplication-tileimage' => :tile
      }.freeze, T::Hash[String, Symbol])

      SIDES = T.let({ 'og:image:width' => :width, 'og:image:height' => :height }.freeze, T::Hash[String, Symbol])

      sig { override.returns(Symbol) }
      def stage
        :document
      end

      sig { override.params(context: Context).returns(T::Array[Icon]) }
      def call(context)
        page = context.page
        page ? collect(page) : []
      end

      private

      sig { params(page: Page).returns(T::Array[Icon]) }
      def collect(page)
        icons = T.let([], T::Array[Icon])
        og_index = T.let(nil, T.nilable(Integer))
        entries(page.document).each do |key, content|
          if (side = SIDES[key])
            icons[og_index] = with_side(T.must(icons[og_index]), side, content.to_i) if og_index
          elsif (icon = build(page, key, content))
            og_index = icons.size if key.start_with?('og:image')
            icons << icon
          end
        end
        icons
      end

      sig { params(document: Nokogiri::HTML5::Document).returns(T::Array[[String, String]]) }
      def entries(document)
        document.css('meta[content]').map do |meta|
          [(meta['property'] || meta['name']).to_s.strip.downcase, meta['content'].to_s.strip]
        end
      end

      sig { params(page: Page, key: String, content: String).returns(T.nilable(Icon)) }
      def build(page, key, content)
        kind = KINDS[key]
        url = page.resolve(content) if kind
        return nil unless kind && url

        Icon.new(url: url, source: :meta_tag, kind: kind, format: ImageFormat.from_url(url))
      end

      sig { params(icon: Icon, side: Symbol, pixels: Integer).returns(Icon) }
      def with_side(icon, side, pixels)
        return icon unless pixels.positive?

        current = icon.dimensions
        dimensions = if side == :width
                       Dimensions.new(width: pixels, height: current.height)
                     else
                       Dimensions.new(width: current.width, height: pixels)
                     end
        icon.with(dimensions: dimensions)
      end
    end
  end
end
