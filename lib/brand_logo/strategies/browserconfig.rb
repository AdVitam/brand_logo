# frozen_string_literal: true
# typed: strict

module BrandLogo
  module Strategies
    class Browserconfig
      extend T::Sig
      include Base

      TILES = T.let({
        'square70x70logo' => [70, 70],
        'square150x150logo' => [150, 150],
        'square310x310logo' => [310, 310],
        'wide310x150logo' => [310, 150]
      }.freeze, T::Hash[String, [Integer, Integer]])

      sig { override.returns(Symbol) }
      def stage
        :remote
      end

      sig { override.params(context: Context).returns(T::Array[Icon]) }
      def call(context)
        response = fetch_config(context)
        document = response && parse(response)
        return [] unless response && document

        document.xpath('//*').filter_map { |node| build(node, response.url) }.uniq(&:url)
      end

      private

      sig { params(context: Context).returns(T.nilable(Http::Response)) }
      def fetch_config(context)
        page = context.page
        return nil unless page

        declared = page.document.at_css('meta[name="msapplication-config"]')&.[]('content').to_s.strip
        url = page.resolve(declared) unless declared.casecmp?('none')
        url && context.get(url)
      end

      sig { params(response: Http::Response).returns(T.nilable(Nokogiri::XML::Document)) }
      def parse(response)
        document = Nokogiri::XML(response.body, &:strict)
        document.remove_namespaces!
        document
      rescue Nokogiri::XML::SyntaxError => e
        Logging.logger.warn("Browserconfig: invalid XML at #{response.url}: #{e.message}")
        nil
      end

      sig { params(node: Nokogiri::XML::Node, config_url: String).returns(T.nilable(Icon)) }
      def build(node, config_url)
        size = TILES[node.name.downcase]
        url = UrlResolver.resolve(node['src'], config_url) if size
        return nil unless size && url

        width, height = size
        Icon.new(
          url: url,
          source: :browserconfig,
          kind: :tile,
          format: ImageFormat.from_url(url),
          dimensions: Dimensions.new(width: width, height: height)
        )
      end
    end
  end
end
