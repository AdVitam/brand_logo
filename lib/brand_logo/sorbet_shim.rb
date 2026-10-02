# frozen_string_literal: true
# typed: ignore

# No-op stand-in for sorbet-runtime so host apps are not forced to depend on it.
# Signatures are only enforced statically (`srb tc`); `sig` blocks are never evaluated.
module T
  module Sig
    def sig(*) = nil
  end

  module Helpers
    def abstract! = nil
    def interface! = nil
  end

  module Boolean; end

  module Generic
    def [](*) = self
  end

  module Array; extend Generic; end
  module Hash; extend Generic; end
  module Range; extend Generic; end

  class << self
    def let(value, _type) = value
    def cast(value, _type) = value

    def must(value)
      raise TypeError, 'Passed `nil` into T.must' if value.nil?

      value
    end

    def nilable(*) = nil
    def any(*) = nil
    def untyped = nil
    def class_of(*) = nil
    def noreturn = nil
    def type_parameter(*) = nil
    def proc = nil
  end
end
