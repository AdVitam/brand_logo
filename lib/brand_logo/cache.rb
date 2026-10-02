# frozen_string_literal: true
# typed: strict

module BrandLogo
  # Duck-typed on read / write(expires_in:) so Rails.cache can be passed as is.
  module Cache
    class Memory
      extend T::Sig

      sig { params(max_entries: Integer).void }
      def initialize(max_entries: 1_000)
        @max_entries = max_entries
        @entries = T.let({}, T::Hash[String, [T.untyped, Float]])
        @mutex = T.let(Mutex.new, Mutex)
      end

      sig { params(key: String).returns(T.untyped) }
      def read(key)
        @mutex.synchronize do
          entry = @entries[key]
          return nil unless entry

          value, expires_at = entry
          return value if now < expires_at

          @entries.delete(key)
          nil
        end
      end

      sig { params(key: String, value: T.untyped, expires_in: T.any(Integer, Float)).void }
      def write(key, value, expires_in:)
        @mutex.synchronize do
          @entries.delete(key)
          @entries[key] = [value, now + expires_in]
          @entries.shift while @entries.size > @max_entries
        end
      end

      private

      sig { returns(Float) }
      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC).to_f
      end
    end
  end
end
