# frozen_string_literal: true
# typed: true

begin
  require 'sorbet-runtime'
rescue LoadError
  require_relative 'sorbet_shim'
end
