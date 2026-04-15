# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::Scraping::DefaultFaviconChecker do
  let(:http_client) { BrandLogo::FakeHttpClient.new }

  subject(:checker) { described_class.new(http_client: http_client) }

  describe '#check' do
    context 'when the URL responds with 2xx' do
      let(:http_client) { BrandLogo::FakeHttpClient.new('https://example.com/favicon.ico' => :head_ok) }

      it 'returns an Icon with the URL and default dimensions' do
        icon = checker.check('https://example.com/favicon.ico')
        expect(icon).not_to be_nil
        expect(icon&.url).to eq('https://example.com/favicon.ico')
        expect(icon&.format).to eq('ico')
        expect(icon&.dimensions).to eq(BrandLogo::Config::DEFAULT_DIMENSIONS)
      end
    end

    context 'when the URL does not respond' do
      it 'returns nil' do
        expect(checker.check('https://example.com/favicon.ico')).to be_nil
      end
    end
  end
end
