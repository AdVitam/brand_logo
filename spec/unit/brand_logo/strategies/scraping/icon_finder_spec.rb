# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::Scraping::IconFinder do
  let(:image_analyzer)          { BrandLogo::FakeImageAnalyzer.new(default: { width: 32, height: 32 }) }
  let(:http_client)             { BrandLogo::FakeHttpClient.new }
  let(:dimensions_extractor)    { BrandLogo::Strategies::Scraping::DimensionsExtractor.new(image_analyzer: image_analyzer) }
  let(:default_favicon_checker) { BrandLogo::Strategies::Scraping::DefaultFaviconChecker.new(http_client: http_client) }

  def make_finder(html)
    doc = BrandLogo::NokogiriParser.new.parse(html)
    described_class.new(
      doc: doc,
      base_url: 'https://example.com',
      dimensions_extractor: dimensions_extractor,
      default_favicon_checker: default_favicon_checker
    )
  end

  describe '#find' do
    context 'with a standard favicon link' do
      let(:html) { '<html><head><link rel="icon" href="/favicon.png" type="image/png"></head></html>' }

      it 'finds the icon' do
        icons = make_finder(html).find
        expect(icons).not_to be_empty
        expect(icons.first&.url).to eq('https://example.com/favicon.png')
        expect(icons.first&.format).to eq('png')
      end
    end

    context 'with an apple-touch-icon' do
      let(:html) { '<html><head><link rel="apple-touch-icon" href="/apple-touch-icon.png" sizes="180x180"></head></html>' }

      it 'finds the icon with correct dimensions' do
        icons = make_finder(html).find
        expect(icons).not_to be_empty
        expect(icons.first&.dimensions).to eq({ width: 180, height: 180 })
      end
    end

    context 'with an absolute favicon URL' do
      let(:html) { '<html><head><link rel="icon" href="https://cdn.example.com/icon.svg" type="image/svg+xml"></head></html>' }

      it 'keeps the absolute URL intact' do
        icons = make_finder(html).find
        expect(icons.first&.url).to eq('https://cdn.example.com/icon.svg')
        expect(icons.first&.format).to eq('svg')
      end
    end

    context 'when no icons are in the HTML' do
      let(:http_client) { BrandLogo::FakeHttpClient.new('https://example.com/favicon.ico' => :head_ok) }
      let(:html) { '<html><head><title>No icons here</title></head></html>' }

      it 'falls back to the default /favicon.ico' do
        icons = make_finder(html).find
        expect(icons).not_to be_empty
        expect(icons.first&.url).to eq('https://example.com/favicon.ico')
      end
    end

    context 'when no icons exist at all' do
      let(:html) { '<html><head></head></html>' }

      it 'returns an empty array' do
        expect(make_finder(html).find).to eq([])
      end
    end
  end
end
