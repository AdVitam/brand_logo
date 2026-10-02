# frozen_string_literal: true
# typed: strict

require 'logger'
require_relative 'sorbet'

module BrandLogo
  module Logging
    extend T::Sig

    @logger = T.let(::Logger.new($stderr, level: ::Logger::WARN), ::Logger)

    sig { returns(::Logger) }
    def self.logger
      @logger
    end

    sig { params(logger: ::Logger).void }
    def self.logger=(logger)
      @logger = logger
    end
  end
end
