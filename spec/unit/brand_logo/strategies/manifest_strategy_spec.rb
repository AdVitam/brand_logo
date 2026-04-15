# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::ManifestStrategy do
  subject(:strategy) do
    described_class.new(
      config: config,
      http_client: http_client,
      html_parser: BrandLogo::NokogiriParser.new,
      image_analyzer: image_analyzer
    )
  end

  let(:config)         { BrandLogo::Config.new }
  let(:image_analyzer) { BrandLogo::FakeImageAnalyzer.new(default: { width: nil, height: nil }) }
  let(:http_client)    { BrandLogo::FakeHttpClient.new(responses) }
  let(:responses)      { {} }

  let(:html_with_manifest) do
    '<html><head><link rel="manifest" href="/manifest.json"></head></html>'
  end
  let(:manifest_json) do
    JSON.generate({
                    'name' => 'Example App',
                    'icons' => [
                      { 'src' => '/icons/icon-192.png', 'sizes' => '192x192', 'type' => 'image/png' },
                      { 'src' => '/icons/icon-512.png', 'sizes' => '512x512', 'type' => 'image/png' },
                      { 'src' => '/icons/icon.svg',     'sizes' => 'any',     'type' => 'image/svg+xml' }
                    ]
                  })
  end

  it_behaves_like 'a favicon strategy'

  describe '#fetch_all' do
    context 'when the page has a manifest with icons' do
      let(:responses) do
        {
          'https://example.com' => html_with_manifest,
          'https://example.com/manifest.json' => manifest_json
        }
      end

      it 'returns icons from the manifest' do
        icons = strategy.fetch_all('example.com')
        expect(icons.length).to eq(3)
      end

      it 'correctly parses the sizes' do
        icons = strategy.fetch_all('example.com')
        png_icons = icons.select { |i| i.format == 'png' }
        expect(png_icons.map(&:dimensions)).to include(
          { width: 192, height: 192 },
          { width: 512, height: 512 }
        )
      end

      it 'resolves relative icon paths to absolute URLs' do
        icons = strategy.fetch_all('example.com')
        expect(icons.map(&:url)).to include('https://example.com/icons/icon-192.png')
      end

      it 'handles "any" sizes as nil dimensions' do
        icons = strategy.fetch_all('example.com')
        svg = icons.find { |i| i.format == 'svg' }
        expect(svg&.dimensions).to eq({ width: nil, height: nil })
      end
    end

    context 'when the page has no manifest tag' do
      let(:responses) { { 'https://example.com' => '<html><head></head></html>' } }

      it 'returns an empty array' do
        expect(strategy.fetch_all('example.com')).to eq([])
      end
    end

    context 'when the manifest JSON is invalid' do
      let(:responses) do
        {
          'https://example.com' => html_with_manifest,
          'https://example.com/manifest.json' => 'not valid json {'
        }
      end

      it 'returns an empty array' do
        expect(strategy.fetch_all('example.com')).to eq([])
      end
    end

    context 'when the manifest has no icons key' do
      let(:responses) do
        {
          'https://example.com' => html_with_manifest,
          'https://example.com/manifest.json' => JSON.generate({ 'name' => 'App' })
        }
      end

      it 'returns an empty array' do
        expect(strategy.fetch_all('example.com')).to eq([])
      end
    end

    context 'when a manifest icon has no MIME type (format inferred from URL)' do
      let(:manifest_without_type) do
        JSON.generate({ 'icons' => [{ 'src' => '/icons/icon-192.png', 'sizes' => '192x192' }] })
      end
      let(:responses) do
        {
          'https://example.com' => html_with_manifest,
          'https://example.com/manifest.json' => manifest_without_type
        }
      end

      it 'infers the format from the URL extension' do
        icons = strategy.fetch_all('example.com')
        expect(icons.first&.format).to eq('png')
      end
    end

    context 'when a manifest icon has a URL invalid for URI parsing' do
      let(:manifest_bad_url) do
        JSON.generate({ 'icons' => [{ 'src' => 'image with spaces.png', 'sizes' => '192x192' }] })
      end
      let(:responses) do
        {
          'https://example.com' => html_with_manifest,
          'https://example.com/manifest.json' => manifest_bad_url
        }
      end

      it 'falls back to png format instead of raising' do
        icons = strategy.fetch_all('example.com')
        expect(icons.first&.format).to eq('png')
      end
    end

    context 'when an unexpected error is raised during fetch' do
      let(:http_client) do
        client = BrandLogo::FakeHttpClient.new
        allow(client).to receive(:get_body).and_raise(StandardError, 'unexpected')
        client
      end

      it 'returns an empty array' do
        expect(strategy.fetch_all('example.com')).to eq([])
      end
    end
  end
end
