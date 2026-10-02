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
