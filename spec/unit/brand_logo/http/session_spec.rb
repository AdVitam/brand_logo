# frozen_string_literal: true

RSpec.describe BrandLogo::Http::Session do
  subject(:session) { described_class.new(config) }

  let(:config) { BrandLogo::Config.new(block_private_ips: false, max_hops: 2, timeout: 5) }
  let(:deadline) { BrandLogo::Deadline.new(10) }
  let(:url) { 'https://example.com/logo.png' }

  after { session.close }

  def fetch(target = url, max_bytes: 1_000, range: nil, deadline: self.deadline)
    session.get(target, deadline: deadline, max_bytes: max_bytes, range: range)
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

  it 'does not leak the Range header into the next request on a reused connection' do
    stub_request(:get, url).to_return(body: 'full')
    stub_request(:get, 'https://example.com/ranged').with(headers: { 'Range' => 'bytes=0-1' })
                                                    .to_return(status: 206, body: 'fu')

    fetch('https://example.com/ranged', range: 0..1)
    fetch

    expect(WebMock).to(have_requested(:get, url).with { |request| !request.headers.key?('Range') })
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
      allow(BrandLogo::Http::UrlGuard).to receive(:web_url?) { |target| !target.include?('internal') }
      stub_request(:get, url).to_return(status: 302, headers: { 'Location' => 'http://internal.example.com/' })
      internal = stub_request(:get, 'http://internal.example.com/').to_return(body: 'secret')

      expect(fetch).to be_nil
      expect(internal).not_to have_been_requested
    end
  end

  it 'checks the url guard before the first request' do
    allow(BrandLogo::Http::UrlGuard).to receive(:web_url?).and_return(false)

    expect(fetch).to be_nil
    expect(BrandLogo::Http::UrlGuard).to have_received(:web_url?).with(url)
  end

  describe 'with block_private_ips' do
    let(:config) { BrandLogo::Config.new(block_private_ips: true, max_hops: 2) }

    def address(ip)
      instance_double(Addrinfo, ip_address: ip)
    end

    before { WebMock.allow_net_connect! }

    it 'connects to the validated address even if the next resolution would be private' do
      allow(Addrinfo).to receive(:getaddrinfo).and_return([address('93.184.216.34')], [address('10.0.0.5')])
      allow(TCPSocket).to receive(:open).and_raise(Errno::ECONNREFUSED)

      expect(fetch).to be_nil
      expect(fetch).to be_nil
      expect(TCPSocket).to have_received(:open).with('93.184.216.34', 443, any_args).twice
      expect(TCPSocket).not_to have_received(:open).with('10.0.0.5', 443, any_args)
      expect(Addrinfo).to have_received(:getaddrinfo).once
    end

    it 'falls back to the next validated address when connecting fails' do
      allow(Addrinfo).to receive(:getaddrinfo).and_return([address('2606:4700:4700::1111'), address('93.184.216.34')])
      allow(TCPSocket).to receive(:open).with('2606:4700:4700::1111', 443, any_args).and_raise(Errno::ENETUNREACH)
      allow(TCPSocket).to receive(:open).with('93.184.216.34', 443, any_args).and_raise(Errno::ECONNREFUSED)

      expect(fetch).to be_nil
      expect(TCPSocket).to have_received(:open).with('93.184.216.34', 443, any_args)
    end

    it 'raises the last error once every validated address fails' do
      allow(Addrinfo).to receive(:getaddrinfo).and_return([address('93.184.216.34'), address('93.184.216.35')])
      allow(TCPSocket).to receive(:open).and_raise(Errno::ECONNREFUSED)

      expect(fetch).to be_nil
      expect(TCPSocket).to have_received(:open).twice
    end

    it 'pins an ip literal to itself' do
      allow(TCPSocket).to receive(:open).and_raise(Errno::ECONNREFUSED)

      expect(fetch('http://[2606:4700:4700::1111]:8080/')).to be_nil
      expect(TCPSocket).to have_received(:open).with('2606:4700:4700::1111', 8080, any_args)
    end

    it 'refuses a redirect to a host resolving to a private address' do
      allow(Addrinfo).to receive(:getaddrinfo) do |host, *|
        [address(host.start_with?('internal') ? '10.0.0.5' : '93.184.216.34')]
      end
      WebMock.disable_net_connect!
      stub_request(:get, url).to_return(status: 302, headers: { 'Location' => 'http://internal.example.com/' })
      internal = stub_request(:get, 'http://internal.example.com/').to_return(body: 'secret')

      expect(fetch).to be_nil
      expect(internal).not_to have_been_requested
    end

    describe 'resolution' do
      before do
        allow(Addrinfo).to receive(:getaddrinfo) do |host, *|
          [address(host.start_with?('internal') ? '10.0.0.5' : '93.184.216.34')]
        end
        WebMock.disable_net_connect!
      end

      def resolved(host)
        expect(Addrinfo).to have_received(:getaddrinfo).with(host, any_args)
      end

      it 'happens once per host across several urls' do
        stub_request(:get, %r{\Ahttps://example\.com/}).to_return(body: 'ok')

        3.times { |index| fetch("https://example.com/#{index}") }

        expect(Addrinfo).to have_received(:getaddrinfo).once
      end

      it 'happens once per host across redirect hops on that host' do
        stub_request(:get, url).to_return(status: 302, headers: { 'Location' => '/a' })
        stub_request(:get, 'https://example.com/a').to_return(status: 302, headers: { 'Location' => '/b' })
        stub_request(:get, 'https://example.com/b').to_return(body: 'end')

        expect(fetch.body).to eq('end')
        expect(Addrinfo).to have_received(:getaddrinfo).once
      end

      it 'happens once per distinct host' do
        stub_request(:get, url).to_return(status: 302, headers: { 'Location' => 'https://cdn.example.com/a' })
        stub_request(:get, 'https://cdn.example.com/a').to_return(body: 'cdn')
        stub_request(:get, 'https://cdn.example.com/b').to_return(body: 'cdn')

        fetch
        fetch('https://cdn.example.com/b')

        resolved('example.com')
        resolved('cdn.example.com')
        expect(Addrinfo).to have_received(:getaddrinfo).twice
      end

      it 'is remembered for a blocked host' do
        2.times { expect(fetch('https://internal.example.com/')).to be_nil }

        expect(Addrinfo).to have_received(:getaddrinfo).once
      end

      it 'is not shared between sessions' do
        stub_request(:get, url).to_return(body: 'ok')
        other = described_class.new(config)

        fetch
        other.get(url, deadline: deadline, max_bytes: 1_000)
        other.close

        expect(Addrinfo).to have_received(:getaddrinfo).twice
      end
    end
  end

  it 'does not pin the connection when private ips are allowed' do
    allow(BrandLogo::Http::UrlGuard).to receive(:validated_addresses)
    allow(Addrinfo).to receive(:getaddrinfo)
    stub_request(:get, url).to_return(body: 'ok')

    expect(fetch.body).to eq('ok')
    expect(BrandLogo::Http::UrlGuard).not_to have_received(:validated_addresses)
    expect(Addrinfo).not_to have_received(:getaddrinfo)
  end

  it 'checks the url guard once per origin when private ips are allowed' do
    allow(BrandLogo::Http::UrlGuard).to receive(:web_url?).and_call_original
    stub_request(:get, %r{\Ahttps://example\.com/}).to_return(body: 'ok')

    2.times { |index| fetch("https://example.com/#{index}") }

    expect(BrandLogo::Http::UrlGuard).to have_received(:web_url?).once
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

  describe 'connection reuse' do
    let(:clients) { [] }
    let(:lock) { Mutex.new }

    before do
      allow(HTTP::Client).to receive(:new).and_wrap_original do |original, *args, **options|
        original.call(*args, **options).tap do |client|
          allow(client).to receive(:close).and_call_original
          lock.synchronize { clients << client }
        end
      end
      stub_request(:get, %r{\Ahttps://example\.com/}).to_return(body: 'ok')
    end

    it 'skips requests once closed' do
      session.close

      expect(fetch('https://example.com/a')).to be_nil
      expect(a_request(:get, 'https://example.com/a')).not_to have_been_made
    end

    it 'serves two requests to the same origin with one client' do
      fetch('https://example.com/a')
      fetch('https://example.com/b')

      expect(clients.size).to eq(1)
      expect(clients.first).not_to have_received(:close)
    end

    it 'uses one client per origin' do
      stub_request(:get, 'https://other.example.org/').to_return(body: 'ok')

      fetch('https://example.com/a')
      fetch('https://other.example.org/')

      expect(clients.size).to eq(2)
    end

    it 'treats another scheme or port as another origin' do
      stub_request(:get, 'http://example.com/').to_return(body: 'ok')
      stub_request(:get, 'https://example.com:8443/').to_return(body: 'ok')

      fetch('https://example.com/a')
      fetch('http://example.com/')
      fetch('https://example.com:8443/')

      expect(clients.size).to eq(3)
    end

    it 'closes the connection and opens a new one after a truncated body' do
      stub_request(:get, 'https://example.com/big').to_return(body: 'a' * 100)

      fetch('https://example.com/big', max_bytes: 10)
      fetch('https://example.com/a')

      expect(clients.size).to eq(2)
      expect(clients.first).to have_received(:close)
    end

    it 'closes the connection and opens a new one after a redirect' do
      stub_request(:get, 'https://example.com/old').to_return(status: 302, headers: { 'Location' => '/a' })

      expect(fetch('https://example.com/old').url).to eq('https://example.com/a')
      expect(clients.size).to eq(2)
      expect(clients.first).to have_received(:close)

      fetch('https://example.com/b')
      expect(clients.size).to eq(2)
    end

    it 'closes the connection and opens a new one after a non-2xx status' do
      stub_request(:get, 'https://example.com/missing').to_return(status: 404, body: 'nope')

      expect(fetch('https://example.com/missing')).to be_nil
      fetch('https://example.com/a')

      expect(clients.size).to eq(2)
      expect(clients.first).to have_received(:close)
    end

    it 'closes the connection and opens a new one after an error' do
      stub_request(:get, 'https://example.com/slow').to_timeout

      expect(fetch('https://example.com/slow')).to be_nil
      expect(fetch('https://example.com/a').body).to eq('ok')

      expect(clients.size).to eq(2)
      expect(clients.first).to have_received(:close)
    end

    it 'reuses a connection for ranged requests' do
      stub_request(:get, 'https://example.com/r').to_return(status: 206, body: 'ab')

      fetch('https://example.com/r', range: 0..1)
      fetch('https://example.com/a')

      expect(clients.size).to eq(1)
    end

    it 'closes every idle client on close' do
      stub_request(:get, 'https://other.example.org/').to_return(body: 'ok')
      fetch('https://example.com/a')
      fetch('https://other.example.org/')

      session.close

      expect(clients).to all(have_received(:close))
    end

    describe 'with a strict deadline' do
      let(:remaining) { { value: 10.0 } }
      let(:deadline) do
        BrandLogo::Deadline.new(10).tap do |real|
          allow(real).to receive(:remaining) { remaining[:value] }
        end
      end

      it 'replaces a pooled connection whose timeout exceeds the remaining time' do
        fetch('https://example.com/a')
        remaining[:value] = 3.0
        fetch('https://example.com/b')

        expect(clients.size).to eq(2)
        expect(clients.first).to have_received(:close)
      end

      it 'keeps a pooled connection whose timeout fits in the remaining time' do
        remaining[:value] = 3.0
        fetch('https://example.com/a')
        remaining[:value] = 10.0
        fetch('https://example.com/b')

        expect(clients.size).to eq(1)
      end
    end

    it 'handles parallel requests to the same origin' do
      stub_request(:get, 'https://example.com/parallel').to_return do
        sleep(0.1)
        { body: 'ok' }
      end

      responses = Array.new(6) { Thread.new { fetch('https://example.com/parallel') } }.map(&:value)

      expect(responses.map { |response| response&.body }).to all(eq('ok'))
      expect(clients.size).to be > 1
    end
  end

  describe 'over real connections' do
    let(:server) { LocalHttpServer.new(body: body, drop_after_response: drop) }
    let(:body) { 'ok' }
    let(:drop) { false }

    before { WebMock.allow_net_connect! }
    after { server.stop }

    it 'serves several requests to one origin over a single connection' do
      bodies = [fetch(server.url('/a')), fetch(server.url('/b'))].map { |response| response&.body }

      expect(bodies).to eq(%w[ok ok])
      expect(server.accepts).to eq(1)
    end

    context 'when the body is truncated' do
      let(:body) { 'a' * 100 }

      it 'opens a new connection for the next request' do
        fetch(server.url('/a'), max_bytes: 10)
        fetch(server.url('/b'), max_bytes: 10)

        expect(server.accepts).to eq(2)
      end
    end

    context 'when the server drops an idle connection' do
      let(:drop) { true }

      it 'replays the request on a new connection' do
        fetch(server.url('/a'))

        expect(fetch(server.url('/b'))&.body).to eq('ok')
        expect(server.accepts).to eq(2)
      end
    end
  end
end
