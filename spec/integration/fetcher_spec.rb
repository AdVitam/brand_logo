# frozen_string_literal: true

RSpec.describe BrandLogo::Fetcher do
  subject(:fetcher) { described_class.new(config: config, http: http) }

  let(:config) { BrandLogo::Config.new(cache: nil) }
  let(:http) { BrandLogo::FakeHttpClient.new(responses) }
  let(:google) { 'https://www.google.com/s2/favicons?domain=example.com&sz=256' }
  let(:duckduckgo) { 'https://icons.duckduckgo.com/ip3/example.com.ico' }

  def html(head)
    "<html><head>#{head}</head><body></body></html>"
  end

  describe '#fetch' do
    context 'when the page links a good icon' do
      let(:responses) do
        {
          'https://example.com' => html('<link rel="icon" href="/icon.png">'),
          'https://example.com/icon.png' => ImageFixtures.png(192, 192)
        }
      end

      it 'returns it with its probed format and size' do
        icon = fetcher.fetch('example.com')
        expect(icon.to_h).to include(url: 'https://example.com/icon.png', format: :png, width: 192, source: :link_tag)
      end

      it 'stops before the manifest and the external services' do
        fetcher.fetch('example.com')
        expect(http.requests).to contain_exactly(
          'https://example.com', 'https://example.com/icon.png', 'https://example.com/favicon.ico'
        )
      end

      it 'accepts a URL as input' do
        expect(fetcher.fetch('https://Example.com/about').url).to eq('https://example.com/icon.png')
      end
    end

    context 'when the favicon is small but the manifest has a large icon' do
      let(:responses) do
        {
          'https://example.com' => html('<link rel="icon" href="/favicon.ico">' \
                                        '<link rel="manifest" href="/app.webmanifest">'),
          'https://example.com/favicon.ico' => ImageFixtures.ico(16, 16),
          'https://example.com/app.webmanifest' => '{"icons":[{"src":"/icon-512.png","sizes":"512x512"}]}',
          'https://example.com/icon-512.png' => ImageFixtures.png(512, 512)
        }
      end

      it 'returns the best icon across stages instead of the first one found' do
        expect(fetcher.fetch('example.com').url).to eq('https://example.com/icon-512.png')
      end
    end

    context 'when a mask-icon SVG sits next to a raster favicon' do
      let(:responses) do
        {
          'https://example.com' => html('<link rel="mask-icon" href="/safari.svg"><link rel="icon" href="/icon.png">'),
          'https://example.com/safari.svg' => ImageFixtures.svg(16, 16),
          'https://example.com/icon.png' => ImageFixtures.png(32, 32)
        }
      end

      it 'prefers the real icon' do
        expect(fetcher.fetch('example.com').url).to eq('https://example.com/icon.png')
      end
    end

    context 'when the linked icon is dead' do
      let(:responses) do
        {
          'https://example.com' => html('<link rel="icon" href="/gone.png">'),
          'https://example.com/favicon.ico' => ImageFixtures.ico(32, 32)
        }
      end

      it 'skips it' do
        expect(fetcher.fetch('example.com').url).to eq('https://example.com/favicon.ico')
      end
    end

    context 'when only the external services know the domain' do
      let(:responses) { { duckduckgo => ImageFixtures.ico(32, 32) } }

      it 'falls back to them' do
        expect(fetcher.fetch('example.com').source).to eq(:duckduckgo)
      end
    end

    context 'when external fallbacks are disabled' do
      let(:config) { BrandLogo::Config.new(cache: nil, external_fallbacks: []) }
      let(:responses) { { duckduckgo => ImageFixtures.ico(32, 32) } }

      it 'does not call them' do
        expect(fetcher.fetch('example.com')).to be_nil
        expect(http.requests).not_to include(duckduckgo, google)
      end
    end

    context 'when nothing is found' do
      let(:responses) { {} }

      it 'returns nil' do
        expect(fetcher.fetch('example.com')).to be_nil
      end
    end

    context 'with invalid input' do
      let(:responses) { {} }

      it 'raises ValidationError' do
        expect { fetcher.fetch('192.168.1.1') }.to raise_error(BrandLogo::ValidationError)
      end
    end
  end

  describe '#fetch!' do
    let(:responses) { {} }

    it 'raises NoIconFoundError when nothing is found' do
      expect { fetcher.fetch!('example.com') }.to raise_error(BrandLogo::NoIconFoundError)
    end
  end

  describe '#fetch_all' do
    let(:responses) do
      {
        'https://example.com' => html('<link rel="icon" href="/icon.png">' \
                                      '<link rel="apple-touch-icon" href="/icon.png">'),
        'https://example.com/icon.png' => ImageFixtures.png(64, 64),
        duckduckgo => ImageFixtures.ico(32, 32)
      }
    end

    it 'returns every valid icon once, best first' do
      expect(fetcher.fetch_all('example.com').map(&:url)).to eq(['https://example.com/icon.png', duckduckgo])
    end
  end

  describe '#fetch_many' do
    let(:responses) do
      {
        'https://example.com' => html('<link rel="icon" href="/icon.png">'),
        'https://example.com/icon.png' => ImageFixtures.png(256, 256)
      }
    end

    it 'maps each original input to its icon' do
      result = fetcher.fetch_many(['example.com', 'https://example.com/', 'unknown.org'])
      expect(result.transform_values { |icon| icon&.url }).to eq(
        'example.com' => 'https://example.com/icon.png',
        'https://example.com/' => 'https://example.com/icon.png',
        'unknown.org' => nil
      )
    end

    it 'validates every input before any request' do
      expect { fetcher.fetch_many(['example.com', 'not a domain']) }.to raise_error(BrandLogo::ValidationError)
      expect(http.requests).to be_empty
    end
  end

  describe 'caching' do
    let(:config) { BrandLogo::Config.new }
    let(:responses) do
      {
        'https://example.com' => html('<link rel="icon" href="/icon.png">'),
        'https://example.com/icon.png' => ImageFixtures.png(256, 256)
      }
    end

    it 'serves repeated lookups from the cache' do
      first = fetcher.fetch('example.com')
      expect { expect(fetcher.fetch('example.com')).to eq(first) }.not_to(change { http.requests.size })
    end

    it 'caches misses too' do
      fetcher.fetch('unknown.org')
      expect { fetcher.fetch('unknown.org') }.not_to(change { http.requests.size })
    end

    it 'does not share entries between fetchers using different strategies' do
      fetcher.fetch('example.com')
      other = described_class.new(config: config, http: http, strategies: [BrandLogo::Strategies::LinkTag.new])
      expect { other.fetch('example.com') }.to(change { http.requests.size })
    end

    it 'does not share entries between configs that rank differently' do
      fetcher.fetch('example.com')
      other = described_class.new(config: config.with(prefer: :largest), http: http)
      expect { other.fetch('example.com') }.to(change { http.requests.size })
    end
  end

  describe 'deadline' do
    let(:config) { BrandLogo::Config.new(cache: BrandLogo::Cache::Memory.new, deadline: 0.05) }
    let(:responses) do
      {
        'https://example.com' => -> { sleep(0.06) && html('<link rel="icon" href="/icon.png">') },
        'https://example.com/icon.png' => ImageFixtures.png(16, 16)
      }
    end

    it 'returns the best icon so far but never caches a lookup cut short' do
      expect(fetcher.fetch('example.com')&.width).to eq(16)
      expect { fetcher.fetch('example.com') }.to(change { http.requests.size })
    end
  end
end
