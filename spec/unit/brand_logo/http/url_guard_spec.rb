# frozen_string_literal: true

RSpec.describe BrandLogo::Http::UrlGuard do
  def allowed?(url, block_private_ips: true)
    described_class.allowed?(url, block_private_ips: block_private_ips)
  end

  def stub_dns(*addresses)
    infos = addresses.map { |address| instance_double(Addrinfo, ip_address: address) }
    allow(Addrinfo).to receive(:getaddrinfo).and_return(infos)
  end

  it 'allows a host resolving to public addresses' do
    stub_dns('93.184.216.34', '2606:2800:220:1:248:1893:25c8:1946')

    expect(allowed?('https://example.com/logo.png')).to be(true)
  end

  it 'rejects non-http schemes and missing hosts' do
    expect(allowed?('ftp://example.com/', block_private_ips: false)).to be(false)
    expect(allowed?('file:///etc/passwd', block_private_ips: false)).to be(false)
    expect(allowed?('http:///path', block_private_ips: false)).to be(false)
    expect(allowed?('not a url', block_private_ips: false)).to be(false)
  end

  it 'only checks scheme and host when private ips are allowed' do
    allow(Addrinfo).to receive(:getaddrinfo)

    expect(allowed?('http://127.0.0.1/', block_private_ips: false)).to be(true)
    expect(Addrinfo).not_to have_received(:getaddrinfo)
  end

  it 'rejects a host when any resolved address is private' do
    stub_dns('93.184.216.34', '10.0.0.5')

    expect(allowed?('https://example.com/')).to be(false)
  end

  it 'rejects when resolution fails or returns nothing' do
    allow(Addrinfo).to receive(:getaddrinfo).and_raise(SocketError)
    expect(allowed?('https://nope.invalid/')).to be(false)

    stub_dns
    expect(allowed?('https://empty.example/')).to be(false)
  end

  %w[
    127.0.0.1 10.1.2.3 172.16.0.1 192.168.1.1 169.254.169.254 0.0.0.0 0.1.2.3 100.64.0.1 224.0.0.1
    255.255.255.255 ::1 :: fe80::1 fc00::1 fd12:3456::1 ::ffff:10.0.0.1 ::ffff:127.0.0.1 ff02::1
  ].each do |address|
    it "rejects #{address} as a resolved address" do
      stub_dns(address)

      expect(allowed?('https://example.com/')).to be(false)
    end
  end

  it 'checks ip literals without resolving them' do
    allow(Addrinfo).to receive(:getaddrinfo)

    urls = %w[http://127.0.0.1:3000/ http://[::1]/ http://[::ffff:192.168.0.1]/ http://8.8.8.8/
              http://[2606:4700:4700::1111]/]

    expect(urls.map { |url| allowed?(url) }).to eq([false, false, false, true, true])
    expect(Addrinfo).not_to have_received(:getaddrinfo)
  end
end
