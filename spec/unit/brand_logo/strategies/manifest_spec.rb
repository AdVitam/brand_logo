# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::Manifest do
  def icons(html, responses = {})
    http = BrandLogo::FakeHttpClient.new({ 'https://example.com' => html }.merge(responses))
    context = BrandLogo::Context.new(domain: 'example.com', config: BrandLogo::Config.new(cache: nil), http: http)
    described_class.new.call(context)
  end

  let(:html) { '<link rel="manifest" href="/static/manifest.json">' }

  it 'runs as a remote stage' do
    expect(described_class.new.stage).to eq(:remote)
  end

  it 'returns nothing when the site is unreachable' do
    context = BrandLogo::Context.new(
      domain: 'example.com', config: BrandLogo::Config.new(cache: nil), http: BrandLogo::FakeHttpClient.new
    )

    expect(described_class.new.call(context)).to eq([])
  end

  it 'reads icons with sizes and types, resolving src against the manifest URL' do
    manifest = '{"icons":[{"src":"icon-192.png","sizes":"192x192","type":"image/png"},' \
               '{"src":"/abs/icon.svg","sizes":"any","type":"image/svg+xml"}]}'
    list = icons(html, 'https://example.com/static/manifest.json' => manifest)

    expect(list.map(&:url)).to eq(%w[https://example.com/static/icon-192.png https://example.com/abs/icon.svg])
    expect(list.first.to_h).to include(width: 192, height: 192, format: :png, kind: :icon, source: :manifest)
    expect(list.last.format).to eq(:svg)
  end

  it 'resolves the manifest link against <base href>' do
    manifest = '{"icons":[{"src":"a.png"}]}'
    list = icons('<base href="/fr/"><link rel="manifest" href="m.json">',
                 'https://example.com/fr/m.json' => manifest)

    expect(list.map(&:url)).to eq(['https://example.com/fr/a.png'])
  end

  it 'infers the format from the extension when type is missing' do
    list = icons(html, 'https://example.com/static/manifest.json' => '{"icons":[{"src":"/a.webp?v=1"}]}')

    expect(list.first.format).to eq(:webp)
  end

  it 'maps purpose to kind' do
    manifest = '{"icons":[{"src":"/a.png","purpose":"monochrome"},{"src":"/b.png","purpose":"maskable"},' \
               '{"src":"/c.png","purpose":"any maskable"},{"src":"/d.png"}]}'
    list = icons(html, 'https://example.com/static/manifest.json' => manifest)

    expect(list.map(&:kind)).to eq(%i[monochrome maskable icon icon])
  end

  it 'ignores non-hash entries and entries without src' do
    manifest = '{"icons":["x",{"sizes":"16x16"},{"src":""},{"src":5},{"src":"/ok.png"}]}'
    list = icons(html, 'https://example.com/static/manifest.json' => manifest)

    expect(list.map(&:url)).to eq(['https://example.com/ok.png'])
  end

  it 'returns nothing for invalid JSON, a non-object or a missing icons array' do
    ['{not json', '[]', '{"icons":"x"}'].each do |body|
      expect(icons(html, 'https://example.com/static/manifest.json' => body)).to eq([])
    end
  end

  it 'logs a warning for invalid JSON' do
    allow(BrandLogo::Logging.logger).to receive(:warn)

    icons(html, 'https://example.com/static/manifest.json' => '{not json')

    expect(BrandLogo::Logging.logger).to have_received(:warn).with(/invalid JSON/)
  end

  it 'returns nothing without a manifest link or when the manifest is unreachable' do
    expect(icons('<html></html>')).to eq([])
    expect(icons(html)).to eq([])
  end
end
