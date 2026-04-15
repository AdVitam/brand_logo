# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::Scraping::DimensionsExtractor do
  subject(:extractor) { described_class.new(image_analyzer: image_analyzer) }

  let(:image_analyzer) { BrandLogo::FakeImageAnalyzer.new(default: { width: 48, height: 48 }) }

  def fake_link(attrs = {})
    double('link', **attrs.transform_values { |v| v }).tap do |d|
      attrs.each { |k, v| allow(d).to receive(:[]).with(k.to_s).and_return(v) }
      allow(d).to receive(:[]).with(anything).and_return(nil) unless attrs.key?(:sizes)
    end
  end

  describe '#extract' do
    context 'when the link has a valid `sizes` attribute' do
      it 'returns dimensions from the attribute without calling image_analyzer' do
        link = double('link')
        allow(link).to receive(:[]).with('sizes').and_return('32x32')

        expect(image_analyzer).not_to receive(:dimensions)
        expect(extractor.extract(link, 'https://example.com/icon.png'))
          .to eq({ width: 32, height: 32 })
      end
    end

    context 'when the `sizes` attribute is absent' do
      it 'falls back to the image_analyzer' do
        link = double('link')
        allow(link).to receive(:[]).with('sizes').and_return(nil)

        result = extractor.extract(link, 'https://example.com/icon.png')
        expect(result).to eq({ width: 48, height: 48 })
      end
    end

    context 'when the `sizes` attribute is malformed' do
      it 'falls back to the image_analyzer' do
        link = double('link')
        allow(link).to receive(:[]).with('sizes').and_return('any')

        result = extractor.extract(link, 'https://example.com/icon.png')
        expect(result).to eq({ width: 48, height: 48 })
      end
    end

    context 'when sizes are zero' do
      it 'falls back to the image_analyzer' do
        link = double('link')
        allow(link).to receive(:[]).with('sizes').and_return('0x0')

        result = extractor.extract(link, 'https://example.com/icon.png')
        expect(result).to eq({ width: 48, height: 48 })
      end
    end
  end
end
