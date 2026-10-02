# frozen_string_literal: true
# typed: strict

module BrandLogo
  module Strategies
    class Duckduckgo
      extend T::Sig
      include Base

      sig { override.returns(Symbol) }
      def stage
        :external
      end

      sig { override.params(context: Context).returns(T::Array[Icon]) }
      def call(context)
        [Icon.new(url: "https://icons.duckduckgo.com/ip3/#{context.domain}.ico", source: :duckduckgo)]
      end
    end
  end
end
