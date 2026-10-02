# frozen_string_literal: true

require 'open3'
require 'rbconfig'

RSpec.describe 'sorbet_shim' do
  def run_ruby(code)
    lib = File.expand_path('../../../lib', __dir__)
    Open3.capture2e(RbConfig.ruby, '--disable-gems', '-I', lib, '-e', "require 'brand_logo/sorbet_shim'\n#{code}")
  end

  it 'loads without sorbet-runtime and keeps T helpers as no-ops' do
    output, status = run_ruby(<<~RUBY)
      class Sample
        extend T::Sig
        extend T::Helpers
        abstract!

        sig { params(value: Integer).returns(Integer) }
        def double(value) = value * 2
      end

      list = T.let([1, 2], T::Array[Integer])
      map = T.let({ a: 1 }, T::Hash[Symbol, Integer])
      puts [Sample.new.double(4), list.inspect, map.to_a.inspect, T.must(5), T.cast('x', String), T::Boolean.class].join('|')
    RUBY

    expect(status).to be_success, output
    expect(output.strip).to eq('8|[1, 2]|[[:a, 1]]|5|x|Module')
  end

  it 'raises TypeError on T.must(nil)' do
    output, status = run_ruby('begin; T.must(nil); rescue TypeError => e; puts e.class; end')

    expect(status).to be_success, output
    expect(output.strip).to eq('TypeError')
  end

  it 'does not define sorbet-runtime only constants' do
    output, = run_ruby('puts defined?(T::Struct).inspect')

    expect(output.strip).to eq('nil')
  end
end
