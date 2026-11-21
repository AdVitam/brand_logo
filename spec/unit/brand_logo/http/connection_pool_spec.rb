# frozen_string_literal: true

RSpec.describe BrandLogo::Http::ConnectionPool do
  subject(:pool) { described_class.new(5) }

  let(:origin) { 'https://example.com' }
  let(:deadline) { BrandLogo::Deadline.new(10) }

  it 'hands back a released entry' do
    entry = pool.open(origin, TCPSocket, deadline)
    pool.release(origin, entry)

    expect(pool.take(origin, deadline)).to eq(entry)
  end

  it 'closes an entry released after the pool was closed' do
    entry = pool.open(origin, TCPSocket, deadline)
    allow(entry.client).to receive(:close)
    pool.close

    pool.release(origin, entry)

    expect(entry.client).to have_received(:close)
    expect(pool.take(origin, deadline)).to be_nil
  end
end
