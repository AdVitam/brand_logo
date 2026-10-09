# frozen_string_literal: true
# typed: strict

require 'json'

module BrandLogo
  module LenientJson
    extend T::Sig

    # json >= 3 rejects duplicate keys and comments by default; json 2.x ignores these options.
    OPTIONS = T.let({ allow_duplicate_key: true, allow_comments: true }.freeze, T::Hash[Symbol, T::Boolean])

    sig { params(text: String).returns(T.untyped) }
    def self.parse(text)
      JSON.parse(text, **OPTIONS)
    end
  end
end
