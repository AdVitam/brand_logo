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
  end
end
