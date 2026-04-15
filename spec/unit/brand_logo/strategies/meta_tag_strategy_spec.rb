# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::MetaTagStrategy do
  subject(:strategy) do
    described_class.new(
      config: config,
      http_client: http_client,
      html_parser: BrandLogo::NokogiriParser.new,
      image_analyzer: image_analyzer
    )
  end

  let(:config)         { BrandLogo::Config.new }
  let(:image_analyzer) { BrandLogo::FakeImageAnalyzer.new(default: { width: 1200, height: 630 }) }
  let(:http_client)    { BrandLogo::FakeHttpClient.new(responses) }
  let(:responses)      { {} }

  it_behaves_like 'a favicon strategy'

  describe '#fetch_all' do
    context 'with an og:image meta tag' do
      let(:html) { '<html><head><meta property="og:image" content="https://example.com/og.jpg"></head></html>' }
      let(:responses) { { 'https://example.com' => html } }

      it 'returns the og:image as an icon' do
        icons = strategy.fetch_all('example.com')
        expect(icons).not_to be_empty
        expect(icons.first&.url).to eq('https://example.com/og.jpg')
        expect(icons.first&.format).to eq('jpg')
      end
    end

    context 'with a twitter:image meta tag' do
      let(:html) { '<html><head><meta name="twitter:image" content="https://example.com/twitter.png"></head></html>' }
      let(:responses) { { 'https://example.com' => html } }

      it 'returns the twitter:image as an icon' do
        icons = strategy.fetch_all('example.com')
        expect(icons.first&.url).to eq('https://example.com/twitter.png')
      end
    end

    context 'when the og:image is a relative URL' do
      let(:html) { '<html><head><meta property="og:image" content="/images/share.jpg"></head></html>' }
      let(:responses) { { 'https://example.com' => html } }

      it 'resolves it to an absolute URL' do
        icons = strategy.fetch_all('example.com')
        expect(icons.first&.url).to eq('https://example.com/images/share.jpg')
      end
    end

    context 'when no meta tags are present' do
      let(:html) { '<html><head><title>No meta here</title></head></html>' }
      let(:responses) { { 'https://example.com' => html } }

      it 'returns an empty array' do
        expect(strategy.fetch_all('example.com')).to eq([])
      end
    end

    context 'when the page cannot be fetched' do
      it 'returns an empty array' do
        expect(strategy.fetch_all('example.com')).to eq([])
      end
    end

    context 'when the og:image URL contains characters invalid for URI parsing' do
      # Spaces in URLs cause URI::InvalidURIError — format falls back to "unknown"
      let(:html) { '<html><head><meta property="og:image" content="https://example.com/image with spaces.jpg"></head></html>' }
      let(:responses) { { 'https://example.com' => html } }

      it 'returns unknown format instead of raising' do
        icons = strategy.fetch_all('example.com')
        expect(icons.first&.format).to eq('unknown')
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
