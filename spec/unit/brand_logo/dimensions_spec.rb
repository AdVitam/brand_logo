# frozen_string_literal: true

RSpec.describe BrandLogo::Dimensions do
  def dims(width, height)
    described_class.new(width: width, height: height)
  end

  describe '.parse' do
    it 'keeps the largest of several sizes' do
      expect(described_class.parse('16x16 32X32')).to eq(dims(32, 32))
    end

    it 'returns unknown for "any"' do
      expect(described_class.parse('any')).not_to be_known
    end

    it 'returns unknown for nil or non strings' do
      expect([described_class.parse(nil), described_class.parse(12)]).to all(eq(described_class.new))
    end

    it 'ignores malformed and zero tokens' do
      expect(described_class.parse('abc 0x0 48x48')).to eq(dims(48, 48))
    end

    it 'handles non square sizes' do
      expect(described_class.parse('100x50')).to eq(dims(100, 50))
    end
  end

  describe '.coerce' do
    it 'passes nil and Dimensions through' do
      value = dims(1, 2)

      expect([described_class.coerce(nil), described_class.coerce(value)]).to eq([nil, value])
    end

    it 'builds a square from an Integer' do
      expect(described_class.coerce(24)).to eq(dims(24, 24))
    end

    it 'builds from a Hash' do
      expect(described_class.coerce({ width: 10, height: 20 })).to eq(dims(10, 20))
    end

    it 'raises on a Hash without keys' do
      expect { described_class.coerce({ width: 10 }) }.to raise_error(KeyError)
    end

    it 'raises on other values' do
      expect { described_class.coerce('10') }.to raise_error(BrandLogo::ValidationError)
    end
  end

  describe 'measures' do
    it 'exposes pair, area and side' do
      value = dims(40, 20)

      expect([value.to_pair, value.area, value.side]).to eq([[40, 20], 800, 20])
    end

    it 'is unknown when a side is missing or zero' do
      expect([dims(nil, 10), dims(10, 0), described_class.new].map(&:known?)).to eq([false, false, false])
    end

    it 'has zero area and side when unknown' do
      value = described_class.new

      expect([value.to_pair, value.area, value.side]).to eq([nil, 0, 0])
    end
  end

  describe 'comparisons' do
    it 'checks at_least? on both sides' do
      expect([dims(32, 32).at_least?(dims(32, 16)), dims(32, 8).at_least?(dims(16, 16))]).to eq([true, false])
    end

    it 'checks at_most? on both sides' do
      expect([dims(16, 16).at_most?(dims(32, 16)), dims(33, 8).at_most?(dims(32, 32))]).to eq([true, false])
    end

    it 'never fails when either side is unknown' do
      unknown = described_class.new

      expect([unknown.at_least?(dims(64, 64)), dims(1, 1).at_most?(unknown),
              dims(1, 1).at_least?(unknown)]).to all(be(true))
    end
  end
end
