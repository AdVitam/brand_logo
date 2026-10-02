# frozen_string_literal: true
# typed: strict

module BrandLogo
  Dimensions = Data.define(:width, :height) do
    extend T::Sig

    sig { params(width: T.nilable(Integer), height: T.nilable(Integer)).void }
    def initialize(width: nil, height: nil)
      super
    end

    sig { params(value: T.untyped).returns(Dimensions) }
    def self.parse(value)
      return new unless value.is_a?(String)

      sizes = value.split.filter_map do |token|
        match = /\A(\d+)x(\d+)\z/i.match(token)
        new(width: match[1].to_i, height: match[2].to_i) if match
      end
      sizes.select(&:known?).max_by(&:area) || new
    end

    sig { params(value: T.untyped).returns(T.nilable(Dimensions)) }
    def self.coerce(value)
      case value
      when nil, Dimensions then value
      when Integer then new(width: value, height: value)
      when ::Hash then new(width: value.fetch(:width), height: value.fetch(:height))
      else raise ValidationError, "Invalid dimensions: #{value.inspect}"
      end
    end

    sig { returns(T.nilable([Integer, Integer])) }
    def to_pair
      w = width
      h = height
      [w, h] if w&.positive? && h&.positive?
    end

    sig { returns(T::Boolean) }
    def known?
      !to_pair.nil?
    end

    sig { returns(Integer) }
    def area
      w, h = to_pair
      w && h ? w * h : 0
    end

    sig { returns(Integer) }
    def side
      to_pair&.min || 0
    end

    sig { params(other: Dimensions).returns(T::Boolean) }
    def at_least?(other)
      compare(other) { |mine, theirs| mine >= theirs }
    end

    sig { params(other: Dimensions).returns(T::Boolean) }
    def at_most?(other)
      compare(other) { |mine, theirs| mine <= theirs }
    end

    private

    # Unknown dimensions on either side never fail a comparison.
    sig { params(other: Dimensions, block: T.proc.params(mine: Integer, theirs: Integer).returns(T::Boolean)).returns(T::Boolean) }
    def compare(other, &block)
      mine = to_pair
      theirs = other.to_pair
      return true unless mine && theirs

      mine.zip(theirs).all? { |m, t| yield(m, T.must(t)) }
    end
  end
end
