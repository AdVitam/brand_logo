# frozen_string_literal: true

RSpec.describe BrandLogo::Fetcher, :e2e do
  subject(:fetcher) { described_class.new }

  it 'finds a usable square icon on popular sites' do
    %w[github.com advitam.fr wikipedia.org shopify.com].each do |domain|
      icon = fetcher.fetch!(domain)
      expect(icon.dimensions.known? ? icon.width : icon.url).to be_truthy, domain
      expect(icon.width).to eq(icon.height), domain if icon.dimensions.known?
    end
  end

  it 'reads JSON-LD logos' do
    expect(fetcher.fetch_all('apple.com').map(&:source)).to include(:json_ld)
  end

  it 'falls back to external services for sites blocking scrapers' do
    expect(fetcher.fetch('leboncoin.fr')).not_to be_nil
  end

  it 'returns nil for an unknown domain' do
    expect(fetcher.fetch('nonexistent-brand-logo-e2e-98765.com')).to be_nil
  end

  it 'never reaches private addresses' do
    local = described_class.new(config: BrandLogo::Config.new(external_fallbacks: []))
    expect(local.fetch('127.0.0.1.nip.io')).to be_nil
  end

  it 'serves repeated lookups from the cache' do
    fetcher.fetch('github.com')
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    fetcher.fetch('github.com')
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.01
  end
end
