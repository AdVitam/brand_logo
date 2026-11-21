# frozen_string_literal: true

RSpec.describe BrandLogo::ImageProbe do
  it 'identifies a PNG and its size' do
    result = described_class.analyze(ImageFixtures.png(32, 16))

    expect(result).to have_attributes(format: :png, dimensions: BrandLogo::Dimensions.new(width: 32, height: 16))
  end

  it 'identifies an ICO' do
    result = described_class.analyze(ImageFixtures.ico(48, 48))

    expect(result).to have_attributes(format: :ico, dimensions: BrandLogo::Dimensions.new(width: 48, height: 48))
  end

  it 'keeps the largest ICO entry even when it is not the first' do
    result = described_class.analyze(ImageFixtures.ico(16, [48, 32], 24))

    expect(result.dimensions).to eq(BrandLogo::Dimensions.new(width: 48, height: 32))
  end

  it 'reads a zero entry size as 256' do
    result = described_class.analyze(ImageFixtures.ico(16, 256))

    expect(result.dimensions).to eq(BrandLogo::Dimensions.new(width: 256, height: 256))
  end

  it 'identifies a CUR as an ICO' do
    result = described_class.analyze(ImageFixtures.ico(32, type: 2))

    expect(result).to have_attributes(format: :ico, dimensions: BrandLogo::Dimensions.new(width: 32, height: 32))
  end

  it 'keeps the complete entries of a truncated ICO directory' do
    result = described_class.analyze(ImageFixtures.ico(16, 64, 128)[0, 6 + (16 * 2) + 5])

    expect(result.dimensions).to eq(BrandLogo::Dimensions.new(width: 64, height: 64))
  end

  it 'returns an ICO with unknown dimensions when the directory is empty' do
    result = described_class.analyze(ImageFixtures.ico)

    expect(result.format).to eq(:ico)
    expect(result.dimensions).not_to be_known
  end

  it 'identifies a CUR cut before its entry count as an ICO' do
    expect(described_class.analyze(ImageFixtures.ico(32, type: 2)[0, 4]).format).to eq(:ico)
  end

  it 'identifies an SVG with explicit dimensions' do
    result = described_class.analyze(ImageFixtures.svg(24, 12))

    expect(result).to have_attributes(format: :svg, dimensions: BrandLogo::Dimensions.new(width: 24, height: 12))
  end

  it 'keeps unknown dimensions when the size cannot be read' do
    result = described_class.analyze(ImageFixtures.png(10, 10)[0, 12])

    expect(result.format).to eq(:png)
    expect(result.dimensions).not_to be_known
  end

  it 'returns nil for an HTML soft 404' do
    expect(described_class.analyze('<!doctype html><html><body>Not found</body></html>')).to be_nil
  end

  it 'returns nil for garbage and empty bodies' do
    expect(described_class.analyze("\x00\x01\x02garbage".b)).to be_nil
    expect(described_class.analyze('')).to be_nil
  end

  it 'returns nil and warns when the parser fails on hostile bytes' do
    allow(FastImage).to receive(:new).and_raise(NoMethodError, 'boom')
    allow(BrandLogo::Logging.logger).to receive(:warn)

    expect(described_class.analyze('x')).to be_nil
    expect(BrandLogo::Logging.logger).to have_received(:warn).with(/NoMethodError: boom/)
  end
end
