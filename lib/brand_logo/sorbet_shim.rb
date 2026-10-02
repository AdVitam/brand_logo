# frozen_string_literal: true
# typed: ignore

# No-op stand-in for sorbet-runtime so host apps are not forced to depend on it.
# Signatures are only enforced statically (`srb tc`); `sig` blocks are never evaluated.
module T
  module Sig
    module WithoutRuntime
      def self.sig(*) = nil
    end

    def sig(*) = nil
  end

  module Helpers
    def abstract! = nil
    def interface! = nil
    def final! = nil
    def sealed! = nil
    def requires_ancestor(*) = nil
    def mixes_in_class_methods(*) = nil
  end

  module Boolean; end

  module Generic
    def [](*) = self
  end

  module Array; extend Generic; end
  module Hash; extend Generic; end
  module Set; extend Generic; end
  module Range; extend Generic; end
  module Enumerable; extend Generic; end
  module Class; extend Generic; end

  class << self
    def let(value, _type) = value
    def cast(value, _type) = value
    def bind(value, _type) = value
    def assert_type!(value, _type) = value
    def unsafe(value) = value

    def must(value)
      raise TypeError, 'Passed `nil` into T.must' if value.nil?

      value
    end

    def nilable(*) = nil
    def any(*) = nil
    def all(*) = nil
    def untyped = nil
    def class_of(*) = nil
    def noreturn = nil
    def anything = nil
    def self_type = nil
    def attached_class = nil
    def type_parameter(*) = nil
    def proc = nil
  end
end
