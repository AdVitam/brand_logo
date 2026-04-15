# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'
require 'fastimage'

module BrandLogo
  # Interface for extracting image dimensions from a URL.
  # Implementations are injected into strategies, enabling testing without network calls.
  module ImageAnalyzer
    extend T::Sig
    extend T::Helpers
    interface!

    sig { abstract.params(url: String).returns(T::Hash[Symbol, T.nilable(Integer)]) }
    def dimensions(url); end
  end

  # Concrete implementation using the FastImage gem.
  # Avoids downloading the full image by parsing only the header bytes.
  class FastimageAnalyzer
    extend T::Sig
    include ImageAnalyzer

    sig { override.params(url: String).returns(T::Hash[Symbol, T.nilable(Integer)]) }
    def dimensions(url)
      result = FastImage.size(url)
      return { width: nil, height: nil } unless result

      { width: result[0], height: result[1] }
    rescue StandardError
      { width: nil, height: nil }
    end
  end
end
