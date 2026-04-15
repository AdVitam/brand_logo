# frozen_string_literal: true

RSpec.describe BrandLogo::ParsedDocument do
  let(:parser) { BrandLogo::NokogiriParser.new }

  describe '#css' do
    let(:doc) do
      parser.parse('<html><head><link rel="icon" href="/icon.ico"><link rel="icon" href="/icon2.ico"></head></html>')
    end

    it 'returns matching elements as an array' do
      elements = doc.css('link[rel="icon"]')
      expect(elements.length).to eq(2)
    end

    it 'returns an empty array when nothing matches' do
      expect(doc.css('meta[property="og:image"]')).to eq([])
    end
  end

  describe '#at' do
    let(:doc) { parser.parse('<html><head><meta property="og:image" content="https://example.com/og.jpg"></head></html>') }

    it 'returns the first matching element' do
      node = doc.at('meta[property="og:image"]')
      expect(node).not_to be_nil
      expect(node['content']).to eq('https://example.com/og.jpg')
    end

    it 'returns nil when nothing matches' do
      expect(doc.at('link[rel="icon"]')).to be_nil
    end
  end

  describe '#base_href' do
    context 'with a <base> tag' do
      let(:doc) { parser.parse('<html><head><base href="https://cdn.example.com/"></head></html>') }

      it 'returns the base href' do
        expect(doc.base_href).to eq('https://cdn.example.com/')
      end
    end

    context 'without a <base> tag' do
      let(:doc) { parser.parse('<html><head></head></html>') }

      it 'returns nil' do
        expect(doc.base_href).to be_nil
      end
    end
  end
end

RSpec.describe BrandLogo::NokogiriParser do
  subject(:parser) { described_class.new }

  describe '#parse' do
    it 'returns a ParsedDocument' do
      result = parser.parse('<html><body>hello</body></html>')
      expect(result).to be_a(BrandLogo::ParsedDocument)
    end
  end
end
