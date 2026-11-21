# frozen_string_literal: true
# typed: strict

require 'fastimage'
require 'stringio'

module BrandLogo
  module ImageProbe
    extend T::Sig

    BYTES = 65_536

    Result = Data.define(:format, :dimensions)

    sig { params(body: String).returns(T.nilable(Result)) }
    def self.analyze(body)
      return icon_result(body) if icon?(body)

      image = FastImage.new(StringIO.new(body), raise_on_failure: false)
      format = ImageFormat.from_fastimage(image.type)
      return nil unless format

      width, height = image.size
      Result.new(format: format, dimensions: Dimensions.new(width: width, height: height))
    # FastImage parses untrusted bytes and can fail outside its own error list.
    rescue StandardError => e
      Logging.logger.warn("ImageProbe: unreadable image (#{e.class}: #{e.message})")
      nil
    end

    sig { params(body: String).returns(T::Boolean) }
    def self.icon?(body)
      body.bytesize >= 4 && (body.unpack('v2') in [0, 1 | 2])
    end

    sig { params(body: String).returns(Result) }
    def self.icon_result(body)
      count = [body.unpack1('@4v').to_i, (body.bytesize - 6) / 16].min
      sizes = Array.new([count, 0].max) do |i|
        width, height = [0, 1].map { |offset| T.must(body.getbyte(6 + (16 * i) + offset)).nonzero? || 256 }
        Dimensions.new(width: width, height: height)
      end
      Result.new(format: :ico, dimensions: sizes.max_by(&:area) || Dimensions.new)
    end

    private_class_method :icon?, :icon_result
  end
end
