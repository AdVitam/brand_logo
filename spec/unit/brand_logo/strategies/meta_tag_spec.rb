# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::MetaTag do
  def icons(head)
    http = BrandLogo::FakeHttpClient.new('https://example.com' => "<html><head>#{head}</head></html>")
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

  it 'reads Open Graph and Twitter images as social, in document order' do
    list = icons('<meta property="og:image" content="/og.png"><meta name="twitter:image" content="/tw.jpg">' \
                 '<meta property="twitter:image:src" content="/tw2.webp">' \
                 '<meta property="og:image:secure_url" content="https://cdn.test/s.png">')

    expect(list.map(&:url)).to eq(%w[https://example.com/og.png https://example.com/tw.jpg
                                     https://example.com/tw2.webp https://cdn.test/s.png])
    expect(list.map(&:kind).uniq).to eq([:social])
    expect(list.map(&:format)).to eq(%i[png jpg webp png])
    expect(list.map(&:source).uniq).to eq([:meta_tag])
  end

  it 'reads og:logo as logo and msapplication-TileImage as tile' do
    list = icons('<meta property="og:logo" content="/logo.png">' \
                 '<meta name="msapplication-TileImage" content="/tile.png">')

    expect(list.map(&:kind)).to eq(%i[logo tile])
  end

  it 'attaches og:image:width and height to the preceding image' do
    list = icons('<meta property="og:image" content="/a.png"><meta property="og:image:width" content="1200">' \
                 '<meta property="og:image:height" content="630"><meta property="og:image" content="/b.png">')

    expect(list.first.dimensions).to have_attributes(width: 1200, height: 630)
    expect(list.last.dimensions).not_to be_known
  end

  it 'never attaches og sizes to a twitter image' do
    list = icons('<meta property="og:image" content="/a.png"><meta name="twitter:image" content="/t.png">' \
                 '<meta property="og:image:width" content="1200">')

    expect(list.map { |icon| icon.dimensions.width }).to eq([1200, nil])
  end

  it 'strips content and ignores empty values' do
    list = icons('<meta property="og:image" content="  /a.png "><meta property="og:image" content="  ">')

    expect(list.map(&:url)).to eq(['https://example.com/a.png'])
  end

  it 'ignores unrelated meta tags' do
    expect(icons('<meta name="description" content="/a.png"><meta property="og:title" content="x">')).to eq([])
  end
end
