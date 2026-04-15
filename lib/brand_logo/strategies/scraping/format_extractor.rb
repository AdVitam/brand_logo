# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module BrandLogo
  module Strategies
    module Scraping
      # Extracts format information from favicon link elements
      class FormatExtractor
        extend T::Sig

        MIME_TO_FORMAT = T.let({
          'image/x-icon' => 'ico',
          'image/vnd.microsoft.icon' => 'ico',
          'image/png' => 'png',
          'image/svg+xml' => 'svg',
          'image/jpeg' => 'jpg',
          'image/webp' => 'webp'
        }.freeze, T::Hash[String, String])

        sig { params(link: Nokogiri::XML::Element).returns(String) }
        def self.extract(link)
          new(link).extract
        end

        sig { params(link: Nokogiri::XML::Element).void }
        def initialize(link)
          @link = link
        end

        sig { returns(String) }
        def extract
          extract_from_mime_type || extract_from_extension
        end

        private

        sig { returns(T.nilable(String)) }
        def extract_from_mime_type
          return nil unless @link['type']

          MIME_TO_FORMAT[@link['type']]
        end

        sig { returns(String) }
        def extract_from_extension
          extension = File.extname(@link['href']).delete('.').downcase
          return 'ico' if extension.empty?

          extension
        end
      end
    end
  end
end
