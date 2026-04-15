# frozen_string_literal: true

RSpec.describe BrandLogo::Fetcher do
  let(:image_analyzer) { BrandLogo::FakeImageAnalyzer.new(default: { width: 32, height: 32 }) }
  let(:http_client)    { BrandLogo::FakeHttpClient.new(responses) }
  let(:config)         { BrandLogo::Config.new }
  let(:responses)      { {} }

  let(:scraping_strategy) do
    BrandLogo::Strategies::ScrapingStrategy.new(
      config: config,
      http_client: http_client,
      html_parser: BrandLogo::NokogiriParser.new,
      image_analyzer: image_analyzer
    )
  end

  let(:duckduckgo_strategy) do
    BrandLogo::Strategies::DuckduckgoStrategy.new(
      config: config,
      http_client: http_client,
      image_analyzer: image_analyzer
    )
  end

  subject(:fetcher) do
    described_class.new(config: config, strategies: [scraping_strategy, duckduckgo_strategy])
  end

  describe '#fetch' do
    context 'when scraping finds an icon' do
      let(:html) { '<html><head><link rel="icon" href="/favicon.ico" sizes="32x32"></head></html>' }
      let(:responses) { { 'https://example.com' => html } }

      it 'returns the icon' do
        icon = fetcher.fetch('example.com')
        expect(icon.url).to eq('https://example.com/favicon.ico')
      end
    end

    context 'when scraping fails but DuckDuckGo has the icon' do
      let(:responses) { { 'https://icons.duckduckgo.com/ip3/example.com.ico' => :head_ok } }

      it 'falls back to DuckDuckGo' do
        icon = fetcher.fetch('example.com')
        expect(icon.url).to include('duckduckgo.com')
      end
    end

    context 'when no strategy finds an icon' do
      it 'raises NoIconFoundError' do
        expect { fetcher.fetch('example.com') }.to raise_error(BrandLogo::NoIconFoundError)
      end
    end

    context 'with an invalid domain' do
      it 'raises ValidationError for empty string' do
        expect { fetcher.fetch('') }.to raise_error(BrandLogo::ValidationError)
      end

      it 'raises ValidationError for an IP address' do
        expect { fetcher.fetch('192.168.1.1') }.to raise_error(BrandLogo::ValidationError)
      end

      it 'accepts a valid domain' do
        html = '<html><head><link rel="icon" href="/favicon.ico" sizes="32x32"></head></html>'
        allow(http_client).to receive(:get_body).with('https://github.com').and_return(html)
        expect { fetcher.fetch('github.com') }.not_to raise_error
      end
    end
  end

  describe '.new with default strategies' do
    it 'instantiates without error (covers build_default_strategies)' do
      fetcher = described_class.new(config: config)
      expect(fetcher).to be_a(described_class)
    end
  end

  describe '#fetch_all' do
    context 'when multiple strategies return icons' do
      let(:html) { '<html><head><link rel="icon" href="/favicon.ico" sizes="32x32"></head></html>' }
      let(:responses) do
        {
          'https://example.com' => html,
          'https://icons.duckduckgo.com/ip3/example.com.ico' => :head_ok
        }
      end

      it 'returns icons from all strategies, deduplicated by URL' do
        icons = fetcher.fetch_all('example.com')
        expect(icons).not_to be_empty
        urls = icons.map(&:url)
        expect(urls.uniq).to eq(urls)
      end
    end
  end
end
