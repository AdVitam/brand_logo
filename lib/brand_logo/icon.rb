# frozen_string_literal: true
# typed: strict

module BrandLogo
  Icon = Data.define(:url, :format, :dimensions, :source, :kind, :media) do
    extend T::Sig

    sig do
      params(
        url: String,
        source: Symbol,
        format: T.nilable(Symbol),
        dimensions: Dimensions,
        kind: Symbol,
        media: T.nilable(String)
      ).void
    end
    def initialize(url:, source:, format: nil, dimensions: Dimensions.new, kind: :icon, media: nil)
      super
    end

    sig { params(hash: T::Hash[T.any(String, Symbol), T.untyped]).returns(Icon) }
    def self.from_h(hash)
      data = hash.transform_keys(&:to_sym)
      new(
        url: data.fetch(:url),
        source: data.fetch(:source).to_sym,
        format: data[:format]&.to_sym,
        dimensions: Dimensions.new(width: data[:width], height: data[:height]),
        kind: data.fetch(:kind, :icon).to_sym,
        media: data[:media]
      )
    end

    sig { returns(T.nilable(Integer)) }
    def width
      dimensions.width
    end

    sig { returns(T.nilable(Integer)) }
    def height
      dimensions.height
    end

    sig { returns(T::Boolean) }
    def svg?
      format == :svg
    end

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def to_h
      { url: url, format: format, width: width, height: height, source: source, kind: kind, media: media }
    end
  end
end
