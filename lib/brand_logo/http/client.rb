# frozen_string_literal: true
# typed: strict

module BrandLogo
  module Http
    module Client
      extend T::Sig
      extend T::Helpers

      abstract!

      # Never raises: any failure is nil, so strategies treat it as "no icon".
      # `max_bytes` still caps the read because servers may ignore `range`.
      sig do
        abstract.params(
          url: String,
          deadline: Deadline,
          max_bytes: Integer,
          range: T.nilable(T::Range[Integer])
        ).returns(T.nilable(Response))
      end
      def get(url, deadline:, max_bytes:, range: nil); end

      # One call per lookup: implementations may pool connections for its duration.
      sig do
        type_parameters(:R).params(
          block: T.proc.params(client: Client).returns(T.type_parameter(:R))
        ).returns(T.type_parameter(:R))
      end
      def session(&block)
        yield self
      end
    end
  end
end
