# frozen_string_literal: true
# typed: strict

module BrandLogo
  module Http
    class RealClient
      extend T::Sig
      include Client

      sig { params(config: Config).void }
      def initialize(config)
        @config = config
      end

      sig do
        override.type_parameters(:R).params(
          block: T.proc.params(client: Client).returns(T.type_parameter(:R))
        ).returns(T.type_parameter(:R))
      end
      def session(&block)
        session = Session.new(@config)
        yield session
      ensure
        session&.close
      end

      sig do
        override.params(
          url: String,
          deadline: Deadline,
          max_bytes: Integer,
          range: T.nilable(T::Range[Integer])
        ).returns(T.nilable(Response))
      end
      def get(url, deadline:, max_bytes:, range: nil)
        session { |client| client.get(url, deadline: deadline, max_bytes: max_bytes, range: range) }
      end
    end
  end
end
