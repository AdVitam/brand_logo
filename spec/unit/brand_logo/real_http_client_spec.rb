# frozen_string_literal: true

RSpec.describe BrandLogo::RealHttpClient do
  subject(:client) { described_class.new(BrandLogo::Config.new(timeout: 2)) }

  # Helper: builds a fake HTTP response with the given status and body
  def fake_response(status_code:, body_text: '')
    status = double('HTTP::Response::Status', success?: (200..299).cover?(status_code))
    body   = double('HTTP::Response::Body', to_s: body_text)
    double('HTTP::Response', status: status, body: body)
  end

  # Helper: stubs the HTTP chained call (timeout → follow → get/head)
  def stub_http_get(url, response)
    chain = double('HTTP::Client')
    allow(HTTP).to receive(:timeout).and_return(chain)
    allow(chain).to receive(:follow).and_return(chain)
    allow(chain).to receive(:get).with(url).and_return(response)
  end

  def stub_http_head(url, response)
    chain = double('HTTP::Client')
    allow(HTTP).to receive(:timeout).and_return(chain)
    allow(chain).to receive(:head).with(url).and_return(response)
  end

  describe '#get_body' do
    context 'when the URL returns a 200 response' do
      before { stub_http_get('https://example.com', fake_response(status_code: 200, body_text: '<html>')) }

      it 'returns the response body' do
        expect(client.get_body('https://example.com')).to eq('<html>')
      end
    end

    context 'when the URL returns a non-2xx response' do
      before { stub_http_get('https://example.com', fake_response(status_code: 404)) }

      it 'returns nil' do
        expect(client.get_body('https://example.com')).to be_nil
      end
    end

    context 'when a network error occurs' do
      before do
        chain = double('HTTP::Client')
        allow(HTTP).to receive(:timeout).and_return(chain)
        allow(chain).to receive(:follow).and_return(chain)
        allow(chain).to receive(:get).and_raise(StandardError, 'timeout')
      end

      it 'returns nil' do
        expect(client.get_body('https://example.com')).to be_nil
      end
    end
  end

  describe '#head_success?' do
    context 'when the URL returns a 200 response' do
      before { stub_http_head('https://example.com', fake_response(status_code: 200)) }

      it 'returns true' do
        expect(client.head_success?('https://example.com')).to be(true)
      end
    end

    context 'when the URL returns a non-2xx response' do
      before { stub_http_head('https://example.com', fake_response(status_code: 404)) }

      it 'returns false' do
        expect(client.head_success?('https://example.com')).to be(false)
      end
    end

    context 'when a network error occurs' do
      before do
        chain = double('HTTP::Client')
        allow(HTTP).to receive(:timeout).and_return(chain)
        allow(chain).to receive(:head).and_raise(StandardError, 'connection refused')
      end

      it 'returns false' do
        expect(client.head_success?('https://example.com')).to be(false)
      end
    end
  end
end
