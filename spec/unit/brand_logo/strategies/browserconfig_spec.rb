# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::Browserconfig do
  def icons(html, responses = {})
    http = BrandLogo::FakeHttpClient.new({ 'https://example.com' => html }.merge(responses))
    context = BrandLogo::Context.new(domain: 'example.com', config: BrandLogo::Config.new(cache: nil), http: http)
    described_class.new.call(context)
  end

  let(:html) { '<meta name="msapplication-config" content="/browserconfig.xml">' }
  let(:xml) do
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <browserconfig><msapplication><tile>
        <square70x70logo src="/t70.png"/>
        <square150x150logo src="t150.png"/>
        <square310x310logo src="/t310.png"/>
        <wide310x150logo src="/w.png"/>
        <TileColor>#ffffff</TileColor>
      </tile></msapplication></browserconfig>
    XML
  end

  it 'runs as a remote stage' do
    expect(described_class.new.stage).to eq(:remote)
  end

  it 'returns nothing when the site is unreachable' do
    context = BrandLogo::Context.new(
      domain: 'example.com', config: BrandLogo::Config.new(cache: nil), http: BrandLogo::FakeHttpClient.new
    )

    expect(described_class.new.call(context)).to eq([])
  end

  it 'reads tile logos with dimensions taken from the element names' do
    list = icons(html, 'https://example.com/browserconfig.xml' => xml)

    expect(list.map(&:url)).to eq(%w[https://example.com/t70.png https://example.com/t150.png
                                     https://example.com/t310.png https://example.com/w.png])
    expect(list.map { |icon| icon.dimensions.to_pair }).to eq([[70, 70], [150, 150], [310, 310], [310, 150]])
    expect(list.map(&:kind).uniq).to eq([:tile])
    expect(list.map(&:source).uniq).to eq([:browserconfig])
    expect(list.first.format).to eq(:png)
  end

  it 'matches camel-cased element names' do
    camel = '<browserconfig><msapplication><tile><Square150x150Logo src="/a.png"/></tile>' \
            '</msapplication></browserconfig>'
    list = icons(html, 'https://example.com/browserconfig.xml' => camel)

    expect(list.map(&:url)).to eq(['https://example.com/a.png'])
  end

  it 'does nothing when the config is "none" or missing' do
    expect(icons('<meta name="msapplication-config" content="none">')).to eq([])
    expect(icons('<html></html>')).to eq([])
  end

  it 'does not request anything when the config is "none"' do
    http = BrandLogo::FakeHttpClient.new('https://example.com' => '<meta name="msapplication-config" content="none">')
    context = BrandLogo::Context.new(domain: 'example.com', config: BrandLogo::Config.new(cache: nil), http: http)

    described_class.new.call(context)

    expect(http.requests).to eq(['https://example.com'])
  end

  it 'returns nothing and warns for invalid XML' do
    allow(BrandLogo::Logging.logger).to receive(:warn)

    expect(icons(html, 'https://example.com/browserconfig.xml' => '<browserconfig><tile>')).to eq([])
    expect(BrandLogo::Logging.logger).to have_received(:warn).with(/invalid XML/)
  end

  it 'returns nothing when the config file is unreachable' do
    expect(icons(html)).to eq([])
  end
end
