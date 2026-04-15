# frozen_string_literal: true

RSpec.describe BrandLogo::FastimageAnalyzer do
  subject(:analyzer) { described_class.new }

  describe '#dimensions' do
    context 'when FastImage returns dimensions' do
      before { allow(FastImage).to receive(:size).with('https://example.com/icon.png').and_return([64, 32]) }

      it 'returns width and height' do
        expect(analyzer.dimensions('https://example.com/icon.png')).to eq({ width: 64, height: 32 })
      end
    end

    context 'when FastImage returns nil' do
      before { allow(FastImage).to receive(:size).and_return(nil) }

      it 'returns nil dimensions' do
        expect(analyzer.dimensions('https://example.com/icon.png')).to eq({ width: nil, height: nil })
      end
    end

    context 'when FastImage raises a StandardError' do
      before { allow(FastImage).to receive(:size).and_raise(StandardError, 'unreachable') }

      it 'returns nil dimensions' do
        expect(analyzer.dimensions('https://example.com/icon.png')).to eq({ width: nil, height: nil })
      end
    end
  end
end
