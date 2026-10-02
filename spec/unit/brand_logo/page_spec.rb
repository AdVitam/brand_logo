# frozen_string_literal: true

RSpec.describe BrandLogo::Page do
  def fetch(responses)
    http = BrandLogo::FakeHttpClient.new(responses)
    context = BrandLogo::Context.new(domain: 'example.com', config: BrandLogo::Config.new(cache: nil), http: http)
    [described_class.fetch(context), http]
  end

  it 'parses the homepage over https' do
    page, http = fetch('https://example.com' => '<html><title>Hi</title></html>')

    expect(page.url).to eq('https://example.com')
    expect(page.base_url).to eq('https://example.com')
    expect(page.document.at_css('title').text).to eq('Hi')
    expect(http.requests).to eq(['https://example.com'])
  end

  it 'returns nil and warns when the homepage is too deeply nested to parse' do
    allow(BrandLogo::Logging.logger).to receive(:warn)
    page, = fetch('https://example.com' => "<html><body>#{'<div>' * 1_000}</body></html>")

    expect(page).to be_nil
    expect(BrandLogo::Logging.logger).to have_received(:warn).with(/cannot parse/)
  end

  it 'falls back to www then http in order' do
    page, http = fetch('http://example.com' => '<html></html>')

    expect(page.url).to eq('http://example.com')
    expect(http.requests).to eq(%w[https://example.com https://www.example.com http://example.com])
  end

  it 'stops at the first answering URL' do
    _page, http = fetch('https://www.example.com' => '<html></html>', 'http://example.com' => '<html></html>')

    expect(http.requests).to eq(%w[https://example.com https://www.example.com])
  end

  it 'returns nil when nothing answers' do
    page, = fetch({})

    expect(page).to be_nil
  end

  it 'uses the final URL after redirects' do
    response = BrandLogo::Http::Response.new(url: 'https://www.example.com/fr/', body: '<html></html>')
    page, = fetch('https://example.com' => response)

    expect(page.url).to eq('https://www.example.com/fr/')
    expect(page.resolve('logo.png')).to eq('https://www.example.com/fr/logo.png')
  end

  it 'resolves hrefs against <base href>' do
    page, = fetch('https://example.com' => '<html><head><base href="/assets/"></head></html>')

    expect(page.base_url).to eq('https://example.com/assets/')
    expect(page.resolve('logo.png')).to eq('https://example.com/assets/logo.png')
  end

  it 'ignores an unusable <base href>' do
    page, = fetch('https://example.com' => '<html><head><base href="javascript:x"></head></html>')

    expect(page.base_url).to eq('https://example.com')
  end
end
