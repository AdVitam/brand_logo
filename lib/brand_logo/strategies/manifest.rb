# frozen_string_literal: true
# typed: strict

require 'json'

module BrandLogo
  module Strategies
    class Manifest
      extend T::Sig
      include Base

      sig { override.returns(Symbol) }
      def stage
        :remote
      end

      sig { override.params(context: Context).returns(T::Array[Icon]) }
      def call(context)
        page = context.page
        return [] unless page

        manifest_url = page.resolve(page.document.at_css('link[rel~="manifest"]')&.[]('href'))
        response = manifest_url && context.get(manifest_url)
        return [] unless response

        icons = parse(response)
        icons.filter_map { |entry| build(entry, response.url) }.uniq(&:url)
      end

      private

      sig { params(response: Http::Response).returns(T::Array[T.untyped]) }
      def parse(response)
        data = JSON.parse(response.body)
        icons = data['icons'] if data.is_a?(::Hash)
        icons.is_a?(::Array) ? icons : []
      rescue JSON::ParserError => e
        Logging.logger.warn("Manifest: invalid JSON at #{response.url}: #{e.message}")
        []
      end

      sig { params(entry: T.untyped, manifest_url: String).returns(T.nilable(Icon)) }
      def build(entry, manifest_url)
        return nil unless entry.is_a?(::Hash)

        url = UrlResolver.resolve(entry['src'], manifest_url) if entry['src'].is_a?(String)
        return nil unless url

        type = entry['type']
        Icon.new(
          url: url,
          source: :manifest,
          kind: kind(entry['purpose']),
          format: ImageFormat.from_mime(type.is_a?(String) ? type : nil) || ImageFormat.from_url(url),
          dimensions: Dimensions.parse(entry['sizes'])
        )
      end

      sig { params(purpose: T.untyped).returns(Symbol) }
      def kind(purpose)
        purposes = purpose.to_s.downcase.split
        if purposes.include?('monochrome') then :monochrome
        elsif purposes.include?('maskable') && !purposes.include?('any') then :maskable
        else :icon
        end
      end
    end
  end
end
