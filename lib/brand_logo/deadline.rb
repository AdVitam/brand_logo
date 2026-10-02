# frozen_string_literal: true
# typed: strict

module BrandLogo
  class Deadline
    extend T::Sig

    sig { params(seconds: Numeric).void }
    def initialize(seconds)
      @expires_at = T.let(now + seconds.to_f, Float)
    end

    sig { returns(Float) }
    def remaining
      [@expires_at - now, 0.0].max
    end

    sig { returns(T::Boolean) }
    def expired?
      remaining.zero?
    end

    private

    sig { returns(Float) }
    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC).to_f
    end
  end
end
