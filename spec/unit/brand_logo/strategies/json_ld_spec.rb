# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::JsonLd do
  def icons(*blocks)
    html = blocks.map { |json| %(<script type="application/ld+json">#{json}</script>) }.join
    http = BrandLogo::FakeHttpClient.new('https://example.com' => "<html>#{html}</html>")
    context = BrandLogo::Context.new(domain: 'example.com', config: BrandLogo::Config.new(cache: nil), http: http)
    described_class.new.call(context)
  end

  it 'runs on the fetched document' do
    expect(described_class.new.stage).to eq(:document)
  end

  it 'returns nothing when the site is unreachable' do
    context = BrandLogo::Context.new(
      domain: 'example.com', config: BrandLogo::Config.new(cache: nil), http: BrandLogo::FakeHttpClient.new
    )

    expect(described_class.new.call(context)).to eq([])
  end

  it 'reads a string logo of an Organization' do
    icon = icons('{"@type":"Organization","logo":"/logo.png"}').first

    expect(icon.to_h).to include(url: 'https://example.com/logo.png', kind: :logo, source: :json_ld, format: :png)
  end

  it 'reads ImageObject logos with url or contentUrl and numeric or px dimensions' do
    list = icons('{"@type":"Corporation","logo":{"@type":"ImageObject","url":"/a.png","width":600,"height":"200px"}}',
                 '{"@type":"Brand","logo":{"contentUrl":"https://cdn.test/b.svg"}}')

    expect(list.map(&:url)).to eq(%w[https://example.com/a.png https://cdn.test/b.svg])
    expect(list.first.dimensions).to have_attributes(width: 600, height: 200)
  end

  it 'reads logo arrays' do
    list = icons('{"@type":"Organization","logo":["/a.png",{"url":"/b.png"}]}')

    expect(list.map(&:url)).to eq(%w[https://example.com/a.png https://example.com/b.png])
  end

  it 'walks @graph arrays and top-level arrays' do
    list = icons('{"@graph":[{"@type":"WebSite"},{"@type":"Organization","logo":"/a.png"}]}',
                 '[{"@type":["Thing","LocalBusiness"],"logo":"/b.png"}]')

    expect(list.map(&:url)).to eq(%w[https://example.com/a.png https://example.com/b.png])
  end

  it 'accepts schema.org type URLs and suffixed types' do
    list = icons('{"@type":"https://schema.org/Organization","logo":"/a.png"}',
                 '{"@type":"NewsMediaOrganization","logo":"/b.png"}',
                 '{"@type":"ClothingStore","logo":"/c.png"}')

    expect(list.size).to eq(3)
  end

  it 'reads logos of nested publisher and brand nodes whatever their type' do
    list = icons('{"@type":"Article","publisher":{"logo":"/a.png"},"brand":{"logo":"/b.png"}}')

    expect(list.map(&:url)).to eq(%w[https://example.com/a.png https://example.com/b.png])
  end

  it 'reads nested organizations such as parentOrganization' do
    list = icons('{"@type":"Organization","parentOrganization":{"@type":"Organization","logo":"/p.png"}}')

    expect(list.map(&:url)).to eq(['https://example.com/p.png'])
  end

  it 'ignores logos of unrelated nodes' do
    expect(icons('{"@type":"Person","logo":"/a.png"}')).to eq([])
  end

  it 'skips invalid JSON and keeps the other scripts' do
    list = icons('{not json', '{"@type":"Organization","logo":"/a.png"}')

    expect(list.map(&:url)).to eq(['https://example.com/a.png'])
  end

  it 'warns about invalid JSON' do
    allow(BrandLogo::Logging.logger).to receive(:warn)
    icons('{not json')

    expect(BrandLogo::Logging.logger).to have_received(:warn).with(/JsonLd: invalid JSON/)
  end

  it 'drops unusable values' do
    list = icons('{"@type":"Organization","logo":["/a.png",{"url":null},"javascript:x",42]}')

    expect(list.map(&:url)).to eq(['https://example.com/a.png'])
  end
end
