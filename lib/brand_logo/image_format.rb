# frozen_string_literal: true
# typed: strict

require 'uri'

module BrandLogo
  module ImageFormat
    extend T::Sig

    MIME_TYPES = T.let({
      'image/x-icon' => :ico,
      'image/vnd.microsoft.icon' => :ico,
      'image/ico' => :ico,
      'image/png' => :png,
      'image/svg+xml' => :svg,
      'image/jpeg' => :jpg,
      'image/jpg' => :jpg,
      'image/webp' => :webp,
      'image/gif' => :gif,
      'image/avif' => :avif,
      'image/bmp' => :bmp
    }.freeze, T::Hash[String, Symbol])

    EXTENSIONS = T.let({
      'ico' => :ico, 'cur' => :ico, 'png' => :png, 'svg' => :svg, 'jpg' => :jpg, 'jpeg' => :jpg,
      'webp' => :webp, 'gif' => :gif, 'avif' => :avif, 'bmp' => :bmp
    }.freeze, T::Hash[String, Symbol])

    FASTIMAGE_TYPES = T.let({ jpeg: :jpg, cur: :ico }.freeze, T::Hash[Symbol, Symbol])

    sig { params(mime: T.untyped).returns(T.nilable(Symbol)) }
    def self.from_mime(mime)
      MIME_TYPES[mime.to_s.split(';').first.to_s.strip.downcase]
    end

    sig { params(url: String).returns(T.nilable(Symbol)) }
    def self.from_url(url)
      return from_mime(url[/\Adata:([^;,]+)/i, 1]) if url.start_with?('data:')

      path = URI.parse(url).path.to_s
      EXTENSIONS[File.extname(path).delete_prefix('.').downcase]
    rescue URI::Error
      nil
    end

    sig { params(type: T.nilable(Symbol)).returns(T.nilable(Symbol)) }
    def self.from_fastimage(type)
      return nil if type.nil?

      FASTIMAGE_TYPES.fetch(type, type)
    end
  end
end
