# frozen_string_literal: true
# typed: strict

require 'logger'
require 'sorbet-runtime'

module BrandLogo
  # Centralized logging for the gem.
  # Replaces the DebugLogger module's debug boolean pattern.
  #
  # Usage:
  #   BrandLogo::Logging.logger.level = Logger::DEBUG  # enable verbose output
  #   BrandLogo::Logging.logger = MyCustomLogger.new   # inject custom logger
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
