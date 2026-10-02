# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::LinkTag do
  def icons(html, responses = {})
    http = BrandLogo::FakeHttpClient.new({ 'https://example.com' => html }.merge(responses))
    context = BrandLogo::Context.new(domain: 'example.com', config: BrandLogo::Config.new(cache: nil), http: http)
    described_class.new.call(context)
  end

  def find(list, url)
    list.find { |icon| icon.url == url }
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

  it 'reads icon links with sizes, type, kind and source' do
    list = icons('<link rel="icon" href="/a.png" sizes="16x16 32x32" type="image/png">')
    icon = find(list, 'https://example.com/a.png')

    expect(icon.to_h).to include(width: 32, height: 32, format: :png, kind: :icon, source: :link_tag)
  end

  it 'resolves relative, absolute and protocol-relative hrefs' do
    list = icons('<link rel="icon" href="a.png"><link rel="icon" href="//cdn.test/b.png">' \
                 '<link rel="icon" href="https://other.test/c.png">')

    expect(list.map(&:url)).to include(
      'https://example.com/a.png', 'https://cdn.test/b.png', 'https://other.test/c.png'
    )
  end

  it 'resolves hrefs against <base href> but favicon.ico against the origin' do
    list = icons('<base href="/fr/"><link rel="icon" href="a.png">')

    expect(list.map(&:url)).to eq(%w[https://example.com/fr/a.png https://example.com/favicon.ico])
  end

  it 'follows the final URL after a redirect' do
    response = BrandLogo::Http::Response.new(url: 'https://www.example.com/fr/', body: '<link rel="icon" href="a.png">')
    list = icons('', 'https://example.com' => response)

    expect(list.map(&:url)).to eq(%w[https://www.example.com/fr/a.png https://www.example.com/favicon.ico])
  end

  it 'classifies apple-touch-icon, precomposed and mask-icon' do
    list = icons('<link rel="apple-touch-icon" href="/a.png"><link rel="apple-touch-icon-precomposed" href="/b.png">' \
                 '<link rel="mask-icon" href="/c.svg">')

    expect(find(list, 'https://example.com/a.png').kind).to eq(:apple_touch)
    expect(find(list, 'https://example.com/b.png').kind).to eq(:apple_touch)
    expect(find(list, 'https://example.com/c.svg')).to have_attributes(kind: :mask, format: :svg)
  end

  it 'matches shortcut icon and mixed-case rel values' do
    list = icons('<link rel="shortcut icon" href="/a.ico"><link rel="ICON" href="/b.png">')

    expect(list.map(&:url)).to include('https://example.com/a.ico', 'https://example.com/b.png')
  end

  it 'ignores links that are not icons, even with an image type' do
    list = icons('<link rel="preload" href="/hero.png" type="image/png"><link rel="stylesheet" href="/a.css">')

    expect(list.map(&:url)).to eq(['https://example.com/favicon.ico'])
  end

  it 'does not duplicate a link matching several rel tokens' do
    list = icons('<link rel="icon apple-touch-icon" href="/a.png">')

    expect(list.count { |icon| icon.url == 'https://example.com/a.png' }).to eq(1)
  end

  it 'keeps the media attribute and handles sizes any' do
    icon = icons('<link rel="icon" href="/d.svg" sizes="any" media="(prefers-color-scheme: dark)">').first

    expect(icon.media).to eq('(prefers-color-scheme: dark)')
    expect(icon.dimensions).not_to be_known
  end

  it 'infers the format from the URL path, ignoring the query string' do
    icon = icons('<link rel="icon" href="/fav.png?v=3">').first

    expect(icon.format).to eq(:png)
  end

  it 'appends /favicon.ico once' do
    list = icons('<link rel="icon" href="/a.png">')
    default = find(list, 'https://example.com/favicon.ico')

    expect(default).to have_attributes(format: :ico, kind: :icon)
    expect(list.size).to eq(2)
  end

  it 'does not add /favicon.ico when a tag already declares it' do
    list = icons('<link rel="icon" href="/favicon.ico" sizes="32x32">')

    expect(list.size).to eq(1)
    expect(list.first.width).to eq(32)
  end

  it 'skips links without href or with unsupported schemes' do
    list = icons('<link rel="icon"><link rel="icon" href="javascript:void(0)">')

    expect(list.map(&:url)).to eq(['https://example.com/favicon.ico'])
  end
end
