# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::Scraping::UrlNormalizer do
  subject(:normalizer) { described_class.new('https://example.com') }

  describe '#normalize' do
    it 'returns absolute URLs unchanged' do
      expect(normalizer.normalize('https://cdn.example.com/icon.png')).to eq('https://cdn.example.com/icon.png')
    end

    it 'returns http:// URLs unchanged' do
      expect(normalizer.normalize('http://example.com/icon.ico')).to eq('http://example.com/icon.ico')
    end

    it 'resolves absolute paths against the base URL' do
      expect(normalizer.normalize('/favicon.ico')).to eq('https://example.com/favicon.ico')
    end

    it 'resolves relative paths against the base URL' do
      expect(normalizer.normalize('images/icon.png')).to eq('https://example.com/images/icon.png')
    end

    it 'returns the href unchanged on URI::Error' do
      malformed = '://bad-url'
      expect(normalizer.normalize(malformed)).to eq(malformed)
    end
  end

  describe '#default_favicon_url' do
    it 'returns the conventional /favicon.ico path' do
      expect(normalizer.default_favicon_url).to eq('https://example.com/favicon.ico')
    end
  end
end
