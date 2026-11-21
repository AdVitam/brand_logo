# frozen_string_literal: true

RSpec.describe BrandLogo::Http::RealClient do
  subject(:client) { described_class.new(config) }

  let(:config) { BrandLogo::Config.new(block_private_ips: false) }
  let(:deadline) { BrandLogo::Deadline.new(10) }
  let(:url) { 'https://example.com/logo.png' }
  let(:response) { BrandLogo::Http::Response.new(url: url, body: 'data') }
  let(:session) { instance_double(BrandLogo::Http::Session, get: response, close: nil) }

  before { allow(BrandLogo::Http::Session).to receive(:new).with(config).and_return(session) }

  describe '#get' do
    it 'delegates to a one-shot session and closes it' do
      expect(client.get(url, deadline: deadline, max_bytes: 10, range: 0..1)).to eq(response)
      expect(session).to have_received(:get).with(url, deadline: deadline, max_bytes: 10, range: 0..1)
      expect(session).to have_received(:close)
    end

    it 'closes the session when the request raises' do
      allow(session).to receive(:get).and_raise(RuntimeError, 'boom')

      expect { client.get(url, deadline: deadline, max_bytes: 10) }.to raise_error(RuntimeError, 'boom')
      expect(session).to have_received(:close)
    end
  end

  describe '#session' do
    it 'yields a session and closes it afterwards' do
      yielded = nil
      client.session { |http| yielded = http }

      expect(yielded).to eq(session)
      expect(session).to have_received(:close)
    end

    it 'returns the block value' do
      expect(client.session { |http| http.get(url, deadline: deadline, max_bytes: 10) }).to eq(response)
    end

    it 'closes the session even when the block raises' do
      expect { client.session { raise 'boom' } }.to raise_error(RuntimeError, 'boom')
      expect(session).to have_received(:close)
    end

    it 'opens a new session each time' do
      2.times { client.session { nil } }

      expect(BrandLogo::Http::Session).to have_received(:new).twice
    end
  end

  it 'fetches over HTTP end to end' do
    allow(BrandLogo::Http::Session).to receive(:new).and_call_original
    stub_request(:get, url).to_return(body: 'data')

    expect(client.get(url, deadline: deadline, max_bytes: 10)).to have_attributes(url: url, body: 'data')
  end
end
