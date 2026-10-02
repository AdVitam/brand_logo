# frozen_string_literal: true

RSpec.describe BrandLogo::ImageFormat do
  describe '.from_mime' do
    it 'maps known MIME types' do
      expect(
        ['image/png', 'image/svg+xml', 'image/x-icon', 'image/vnd.microsoft.icon', 'image/jpeg'].map do |m|
          described_class.from_mime(m)
        end
      ).to eq(%i[png svg ico ico jpg])
    end

    it 'ignores parameters and case' do
      expect(described_class.from_mime('IMAGE/PNG; charset=binary')).to eq(:png)
    end

    it 'returns nil for nil and unknown types' do
      expect([described_class.from_mime(nil), described_class.from_mime('text/html')]).to eq([nil, nil])
    end

    it 'returns nil for empty types' do
      expect(['', ';', ' '].map { |mime| described_class.from_mime(mime) }).to eq([nil, nil, nil])
    end
  end

  describe '.from_url' do
    it 'reads the path extension' do
      expect(described_class.from_url('https://x.test/a/logo.SVG')).to eq(:svg)
    end

    it 'ignores the query string' do
      expect(described_class.from_url('https://x.test/fav.png?v=3')).to eq(:png)
    end

    it 'normalises jpeg and cur' do
      expect([described_class.from_url('/a.jpeg'), described_class.from_url('/a.cur')]).to eq(%i[jpg ico])
    end

    it 'reads data: URI media types' do
      expect(described_class.from_url('data:image/png;base64,AAAA')).to eq(:png)
      expect(described_class.from_url('data:image/svg+xml,%3Csvg%3E')).to eq(:svg)
    end

    it 'returns nil without a known extension' do
      expect([described_class.from_url('https://x.test/logo'),
              described_class.from_url('https://x.test/a.txt')]).to eq([nil, nil])
    end

    it 'returns nil for unparsable URLs' do
      expect(described_class.from_url('http://[bad')).to be_nil
    end
  end

  describe '.from_fastimage' do
    it 'maps FastImage types' do
      expect([described_class.from_fastimage(:jpeg), described_class.from_fastimage(:cur),
              described_class.from_fastimage(:png)]).to eq(%i[jpg ico png])
    end

    it 'returns nil for nil' do
      expect(described_class.from_fastimage(nil)).to be_nil
    end
  end
end
