# frozen_string_literal: true
# typed: strict

module BrandLogo
  module Strategies
    module Base
      extend T::Sig
      extend T::Helpers

      interface!

      sig { abstract.returns(Symbol) }
      def stage; end

      sig { abstract.params(context: Context).returns(T::Array[Icon]) }
      def call(context); end
    end
  end
end
