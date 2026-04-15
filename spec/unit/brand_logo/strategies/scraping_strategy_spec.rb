# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::ScrapingStrategy do
  let(:config)         { BrandLogo::Config.new }
  let(:image_analyzer) { BrandLogo::FakeImageAnalyzer.new(default: { width: 32, height: 32 }) }
  let(:html_parser)    { BrandLogo::NokogiriParser.new }
  let(:http_client)    { BrandLogo::FakeHttpClient.new(responses) }

  subject(:strategy) do
    described_class.new(
      config: config,
      http_client: http_client,
      html_parser: html_parser,
      image_analyzer: image_analyzer
    )
  end

  include_examples 'a favicon strategy'

  let(:responses) { {} }

  describe '#fetch_all' do
    context 'when the HTTPS page has a favicon' do
      let(:html) { '<html><head><link rel="icon" href="/favicon.png" type="image/png" sizes="64x64"></head></html>' }
      let(:responses) { { 'https://example.com' => html } }

      it 'returns the favicon' do
        icons = strategy.fetch_all('example.com')
        expect(icons).not_to be_empty
        expect(icons.first&.url).to eq('https://example.com/favicon.png')
        expect(icons.first&.format).to eq('png')
        expect(icons.first&.dimensions).to eq({ width: 64, height: 64 })
      end
    end

    context 'when HTTPS fails but www.domain works' do
      let(:html) { '<html><head><link rel="icon" href="/icon.ico"></head></html>' }
      let(:responses) { { 'https://www.example.com' => html } }

      it 'retries with www prefix' do
        icons = strategy.fetch_all('example.com')
        expect(icons).not_to be_empty
        expect(icons.first&.url).to eq('https://www.example.com/icon.ico')
      end
    end

    context 'when HTTPS fails but HTTP works' do
      let(:html) { '<html><head><link rel="icon" href="/icon.ico"></head></html>' }
      let(:responses) { { 'http://example.com' => html } }

      it 'falls back to HTTP' do
        icons = strategy.fetch_all('example.com')
        expect(icons).not_to be_empty
      end
    end

    context 'when no page responds' do
      it 'returns an empty array' do
        expect(strategy.fetch_all('example.com')).to eq([])
      end
    end

    context 'with min_dimensions filter' do
      let(:config) { BrandLogo::Config.new(min_dimensions: { width: 64, height: 64 }) }
      let(:html) { '<html><head><link rel="icon" href="/small.png" type="image/png" sizes="16x16"></head></html>' }
      let(:responses) { { 'https://example.com' => html } }

      it 'excludes icons smaller than the minimum' do
        expect(strategy.fetch('example.com')).to be_nil
      end
    end

    context 'with max_dimensions filter' do
      let(:config) { BrandLogo::Config.new(max_dimensions: { width: 32, height: 32 }) }
      let(:html) { '<html><head><link rel="icon" href="/large.png" type="image/png" sizes="256x256"></head></html>' }
      let(:responses) { { 'https://example.com' => html } }

      it 'excludes icons larger than the maximum' do
        expect(strategy.fetch('example.com')).to be_nil
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

  describe '#fetch' do
    context 'with multiple icons' do
      let(:html) do
        <<~HTML
          <html><head>
            <link rel="icon" href="/small.ico" sizes="16x16">
            <link rel="icon" href="/large.png" type="image/png" sizes="192x192">
          </head></html>
        HTML
      end
      let(:responses) { { 'https://example.com' => html } }

      it 'returns the largest icon' do
        icon = strategy.fetch('example.com')
        expect(icon&.url).to eq('https://example.com/large.png')
      end
    end

    context 'with allow_svg: true and an SVG icon' do
      let(:config) { BrandLogo::Config.new(allow_svg: true) }
      let(:html) do
        <<~HTML
          <html><head>
            <link rel="icon" href="/large.png" type="image/png" sizes="512x512">
            <link rel="icon" href="/icon.svg" type="image/svg+xml">
          </head></html>
        HTML
      end
      let(:responses) { { 'https://example.com' => html } }

      it 'prefers SVG over larger raster icons' do
        icon = strategy.fetch('example.com')
        expect(icon&.format).to eq('svg')
      end
    end

    context 'with allow_svg: false' do
      let(:config) { BrandLogo::Config.new(allow_svg: false) }
      let(:html) do
        <<~HTML
          <html><head>
            <link rel="icon" href="/icon.svg" type="image/svg+xml">
            <link rel="icon" href="/icon.png" type="image/png" sizes="32x32">
          </head></html>
        HTML
      end
      let(:responses) { { 'https://example.com' => html } }

      it 'skips SVG icons' do
        icon = strategy.fetch('example.com')
        expect(icon&.format).to eq('png')
      end
    end
  end
end
