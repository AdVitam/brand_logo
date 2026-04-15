# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::DuckduckgoStrategy do
  let(:config)         { BrandLogo::Config.new }
  let(:image_analyzer) { BrandLogo::FakeImageAnalyzer.new(default: { width: nil, height: nil }) }
  let(:http_client)    { BrandLogo::FakeHttpClient.new }

  subject(:strategy) do
    described_class.new(
      config: config,
      http_client: http_client,
      image_analyzer: image_analyzer
    )
  end

  include_examples 'a favicon strategy'

  describe '#fetch_all' do
    context 'when DuckDuckGo has the icon' do
      let(:http_client) { BrandLogo::FakeHttpClient.new('https://icons.duckduckgo.com/ip3/example.com.ico' => :head_ok) }

      it 'returns the DuckDuckGo icon URL' do
        icons = strategy.fetch_all('example.com')
        expect(icons.length).to eq(1)
        expect(icons.first&.url).to eq('https://icons.duckduckgo.com/ip3/example.com.ico')
        expect(icons.first&.format).to eq('ico')
      end
    end

    context 'when DuckDuckGo does not have the icon' do
      it 'returns an empty array' do
        expect(strategy.fetch_all('example.com')).to eq([])
      end
    end

    context 'when an unexpected error is raised' do
      let(:http_client) do
        client = BrandLogo::FakeHttpClient.new
        allow(client).to receive(:head_success?).and_raise(StandardError, 'unexpected')
        client
      end

      it 'returns an empty array' do
        expect(strategy.fetch_all('example.com')).to eq([])
      end
    end
  end
end
