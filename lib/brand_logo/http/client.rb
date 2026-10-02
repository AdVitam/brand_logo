# frozen_string_literal: true
# typed: strict

module BrandLogo
  module Http
    module Client
      extend T::Sig
      extend T::Helpers

      interface!

      # Returns the response for a 2xx status, nil otherwise (network error, blocked URL, non-2xx, deadline).
      # `max_bytes` caps how much of the body is read; `range` sends a Range header (servers may ignore it).
      sig do
        abstract.params(
          url: String,
          deadline: Deadline,
          max_bytes: Integer,
          range: T.nilable(T::Range[Integer])
        ).returns(T.nilable(Response))
      end
      def get(url, deadline:, max_bytes:, range: nil); end
    end
  end
end
