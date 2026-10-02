# frozen_string_literal: true

RSpec.describe BrandLogo::Icon do
  subject(:icon) do
    described_class.new(
      url: 'https://x.test/a.png', source: :link_tag, format: :png,
      dimensions: BrandLogo::Dimensions.new(width: 32, height: 16), kind: :apple_touch,
      media: '(prefers-color-scheme: dark)'
    )
  end

  it 'applies defaults' do
    built = described_class.new(url: 'https://x.test/a.png', source: :manifest)

    expect(built).to have_attributes(format: nil, kind: :icon, media: nil, dimensions: BrandLogo::Dimensions.new)
  end

  it 'exposes width and height from its dimensions' do
    expect([icon.width, icon.height]).to eq([32, 16])
  end

  it 'detects svg' do
    expect([icon.svg?, icon.with(format: :svg).svg?]).to eq([false, true])
  end

  describe '#to_h and .from_h' do
    it 'serialises flat' do
      expect(icon.to_h).to eq(
        url: 'https://x.test/a.png', format: :png, width: 32, height: 16, source: :link_tag,
        kind: :apple_touch, media: '(prefers-color-scheme: dark)'
      )
    end

    it 'round-trips with symbol keys' do
      expect(described_class.from_h(icon.to_h)).to eq(icon)
    end

    it 'round-trips with string keys and string symbols' do
      hash = icon.to_h.transform_keys(&:to_s).merge('source' => 'link_tag', 'format' => 'png', 'kind' => 'apple_touch')

      expect(described_class.from_h(hash)).to eq(icon)
    end

    it 'defaults kind and tolerates missing optional keys' do
      built = described_class.from_h('url' => 'https://x.test/a.ico', 'source' => 'google')

      expect(built).to have_attributes(kind: :icon, format: nil, media: nil, source: :google)
    end

    it 'requires url and source' do
      expect { described_class.from_h({ 'url' => 'x' }) }.to raise_error(KeyError)
    end
  end
end
