# frozen_string_literal: true

RSpec.describe BrandLogo::Http::RealClient do
  let(:config) { BrandLogo::Config.new(block_private_ips: false, max_hops: 2) }
  let(:client) { described_class.new(config) }
  let(:deadline) { BrandLogo::Deadline.new(10) }
  let(:url) { 'https://example.com/logo.png' }

  def fetch(target = url, max_bytes: 1_000, range: nil, deadline: self.deadline)
    client.get(target, deadline: deadline, max_bytes: max_bytes, range: range)
  end

  it 'returns the body and final url on success' do
    stub_request(:get, url).to_return(status: 200, body: 'data')

    expect(fetch).to have_attributes(url: url, body: 'data')
  end

  it 'returns nil for a non-2xx status' do
    stub_request(:get, url).to_return(status: 404, body: 'nope')

    expect(fetch).to be_nil
  end

  it 'accepts a partial content response' do
    stub_request(:get, url).to_return(status: 206, body: 'ab')

    expect(fetch(range: 0..1)&.body).to eq('ab')
  end

  it 'sends the configured user agent and an Accept header' do
    stub_request(:get, url).with(headers: { 'User-Agent' => config.user_agent, 'Accept' => %r{image/\*} })
                           .to_return(body: 'ok')

    expect(fetch.body).to eq('ok')
  end

  it 'sends a Range header when a range is given' do
    stub = stub_request(:get, url).with(headers: { 'Range' => 'bytes=0-99' }).to_return(status: 206, body: 'x')

    fetch(range: 0..99)

    expect(stub).to have_been_requested
  end

  it 'truncates the body at max_bytes' do
    stub_request(:get, url).to_return(body: 'a' * 100)

    expect(fetch(max_bytes: 10).body).to eq('a' * 10)
  end

  describe 'redirects' do
    it 'follows them and reports the final url' do
      stub_request(:get, url).to_return(status: 301, headers: { 'Location' => 'https://cdn.example.com/a.png' })
      stub_request(:get, 'https://cdn.example.com/a.png').to_return(body: 'final')

      expect(fetch).to have_attributes(url: 'https://cdn.example.com/a.png', body: 'final')
    end

    it 'resolves a relative Location against the current url' do
      stub_request(:get, url).to_return(status: 302, headers: { 'Location' => '/static/logo.png' })
      stub_request(:get, 'https://example.com/static/logo.png').to_return(body: 'rel')

      expect(fetch.url).to eq('https://example.com/static/logo.png')
    end

    it 'returns nil after too many hops' do
      stub_request(:get, /example\.com/).to_return(status: 302, headers: { 'Location' => '/loop' })

      expect(fetch).to be_nil
    end

    it 'returns nil when a redirect has no Location' do
      stub_request(:get, url).to_return(status: 302)

      expect(fetch).to be_nil
    end

    it 'returns nil when a hop targets a blocked url' do
      allow(BrandLogo::Http::UrlGuard).to receive(:allowed?) { |target, **| !target.include?('internal') }
      stub_request(:get, url).to_return(status: 302, headers: { 'Location' => 'http://internal.example.com/' })
      internal = stub_request(:get, 'http://internal.example.com/').to_return(body: 'secret')

      expect(fetch).to be_nil
      expect(internal).not_to have_been_requested
    end
  end

  it 'checks the url guard before the first request' do
    allow(BrandLogo::Http::UrlGuard).to receive(:allowed?).and_return(false)

    expect(fetch).to be_nil
    expect(BrandLogo::Http::UrlGuard).to have_received(:allowed?).with(url, block_private_ips: false)
  end

  it 'returns nil on a timeout' do
    stub_request(:get, url).to_timeout

    expect(fetch).to be_nil
  end

  it 'returns nil on a connection error' do
    stub_request(:get, url).to_raise(Errno::ECONNREFUSED)

    expect(fetch).to be_nil
  end

  it 'returns nil for an invalid url' do
    expect(fetch('http://exa mple.com/')).to be_nil
  end

  it 'returns nil without any request once the deadline is expired' do
    stub = stub_request(:get, url)

    expect(fetch(deadline: BrandLogo::Deadline.new(0))).to be_nil
    expect(stub).not_to have_been_requested
  end
end
