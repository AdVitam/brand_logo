# frozen_string_literal: true
# typed: strict

require 'cgi'

module BrandLogo
  module Strategies
    # Google's favicon service answers 404 for unknown domains, which the probe drops.
    class Google
      extend T::Sig
      include Base

      SIZE = 256

      sig { override.returns(Symbol) }
      def stage
        :external
      end

      sig { override.params(context: Context).returns(T::Array[Icon]) }
      def call(context)
        [Icon.new(
          url: "https://www.google.com/s2/favicons?domain=#{CGI.escape(context.domain)}&sz=#{SIZE}",
          source: :google
        )]
      end
    end
  end
end
