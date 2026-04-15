# frozen_string_literal: true

RSpec.describe BrandLogo::Icon do
  subject(:icon) do
    described_class.new(
      url: 'https://example.com/favicon.png',
      dimensions: { width: 32, height: 32 },
      format: 'png'
    )
  end

  it { expect(icon.url).to eq('https://example.com/favicon.png') }
  it { expect(icon.dimensions).to eq({ width: 32, height: 32 }) }
  it { expect(icon.format).to eq('png') }

  describe 'with nil dimensions' do
    subject(:icon) do
      described_class.new(
        url: 'https://example.com/favicon.ico',
        dimensions: { width: nil, height: nil },
        format: 'ico'
      )
    end

    it { expect(icon.dimensions[:width]).to be_nil }
    it { expect(icon.dimensions[:height]).to be_nil }
  end
end
