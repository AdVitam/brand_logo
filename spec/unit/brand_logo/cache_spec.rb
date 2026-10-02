# frozen_string_literal: true

RSpec.describe BrandLogo::Cache::Memory do
  subject(:cache) { described_class.new(max_entries: 3) }

  def travel(seconds)
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    allow(Process).to receive(:clock_gettime).and_call_original
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(now + seconds)
  end

  it 'returns nil for a missing key' do
    expect(cache.read('missing')).to be_nil
  end

  it 'returns a written value' do
    cache.write('a', { url: 'x' }, expires_in: 60)

    expect(cache.read('a')).to eq({ url: 'x' })
  end

  it 'distinguishes a stored false from a missing key' do
    cache.write('a', false, expires_in: 60)

    expect(cache.read('a')).to be(false)
  end

  it 'expires entries' do
    cache.write('a', 1, expires_in: 10)
    travel(11)

    expect(cache.read('a')).to be_nil
  end

  it 'keeps entries before expiry' do
    cache.write('a', 1, expires_in: 10)
    travel(5)

    expect(cache.read('a')).to eq(1)
  end

  it 'evicts the oldest entries beyond max_entries' do
    %w[a b c d].each { |key| cache.write(key, key, expires_in: 60) }

    expect(%w[a b c d].map { |key| cache.read(key) }).to eq([nil, 'b', 'c', 'd'])
  end

  it 'keeps recently rewritten keys' do
    %w[a b c].each { |key| cache.write(key, key, expires_in: 60) }
    cache.write('a', 'a2', expires_in: 60)
    cache.write('d', 'd', expires_in: 60)

    expect(%w[a b c d].map { |key| cache.read(key) }).to eq(['a2', nil, 'c', 'd'])
  end

  it 'is safe under concurrent writes' do
    big = described_class.new(max_entries: 50)
    Array.new(4) { |t| Thread.new { 200.times { |i| big.write("k#{t}-#{i}", i, expires_in: 60) } } }.each(&:join)

    keys = Array.new(4) { |t| Array.new(200) { |i| "k#{t}-#{i}" } }.flatten
    expect(keys.count { |key| big.read(key) }).to be_between(1, 50)
  end
end
