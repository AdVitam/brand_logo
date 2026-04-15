# frozen_string_literal: true

RSpec.describe BrandLogo::Config do
  describe '.new' do
    context 'with default values' do
      subject(:config) { described_class.new }

      it { expect(config.min_dimensions).to eq({ width: 0, height: 0 }) }
      it { expect(config.max_dimensions).to be_nil }
      it { expect(config.allow_svg).to be(true) }
      it { expect(config.timeout).to eq(10) }
      it { expect(config.max_hops).to eq(5) }
    end

    context 'with custom values' do
      subject(:config) do
        described_class.new(
          min_dimensions: { width: 32, height: 32 },
          max_dimensions: { width: 256, height: 256 },
          allow_svg: false,
          timeout: 3,
          max_hops: 2
        )
      end

      it { expect(config.min_dimensions).to eq({ width: 32, height: 32 }) }
      it { expect(config.max_dimensions).to eq({ width: 256, height: 256 }) }
      it { expect(config.allow_svg).to be(false) }
      it { expect(config.timeout).to eq(3) }
      it { expect(config.max_hops).to eq(2) }
    end
  end

  describe 'constants' do
    it { expect(described_class::DEFAULT_TIMEOUT).to eq(10) }
    it { expect(described_class::DEFAULT_MAX_HOPS).to eq(5) }
    it { expect(described_class::DEFAULT_FAVICON_PATH).to eq('/favicon.ico') }
    it { expect(described_class::DEFAULT_DIMENSIONS).to eq({ width: 16, height: 16 }) }
  end
end
