# frozen_string_literal: true

RSpec.describe BrandLogo::Config do
  subject(:config) { described_class.new }

  describe 'defaults' do
    it 'has sensible defaults' do
      expect(config).to have_attributes(
        min_size: nil, max_size: nil, allow_svg: true, prefer: :square, target_size: nil, color_scheme: nil,
        timeout: 5, deadline: 15, max_hops: 5, concurrency: 4, block_private_ips: true,
        cache_ttl: 86_400, negative_cache_ttl: 3_600, user_agent: described_class::USER_AGENT
      )
    end

    it 'uses an in-memory cache' do
      expect(config.cache).to be_a(BrandLogo::Cache::Memory)
    end

    it 'enables every external fallback and freezes the list' do
      expect(config.external_fallbacks).to eq(%i[google duckduckgo])
      expect(config.external_fallbacks).to be_frozen
    end

    it 'does not freeze or alias the caller array' do
      list = [:google]
      built = described_class.new(external_fallbacks: list)

      expect(list).not_to be_frozen
      expect(built.external_fallbacks).to equal(built.external_fallbacks)
      expect(built.external_fallbacks).not_to equal(list)
    end
  end

  describe 'size coercion' do
    it 'turns an Integer into a square Dimensions' do
      expect(described_class.new(min_size: 32).min_size).to eq(BrandLogo::Dimensions.new(width: 32, height: 32))
    end

    it 'turns a Hash into Dimensions' do
      built = described_class.new(max_size: { width: 512, height: 256 })

      expect(built.max_size).to eq(BrandLogo::Dimensions.new(width: 512, height: 256))
    end

    it 'keeps a Dimensions as is' do
      dims = BrandLogo::Dimensions.new(width: 16, height: 16)

      expect(described_class.new(min_size: dims).min_size).to equal(dims)
    end

    it 'rejects other types' do
      expect { described_class.new(min_size: 'big') }.to raise_error(BrandLogo::ValidationError, /Invalid dimensions/)
    end
  end

  describe 'validation' do
    {
      'prefer must be one of' => { prefer: :tiny },
      'color_scheme must be nil or one of' => { color_scheme: :sepia },
      'external_fallbacks must be within' => { external_fallbacks: [:bing] },
      'target_size must be positive' => { target_size: 0 },
      'timeout must be positive' => { timeout: 0 },
      'deadline must be positive' => { deadline: -1 },
      'max_body_bytes must be positive' => { max_body_bytes: 0 },
      'concurrency must be positive' => { concurrency: 0 },
      'max_hops must be >= 0' => { max_hops: -1 },
      'cache_ttl must be >= 0' => { cache_ttl: -1 },
      'negative_cache_ttl must be >= 0' => { negative_cache_ttl: -1 },
      'cache must respond to read/write' => { cache: Object.new },
      'max_size must be >= min_size' => { min_size: 64, max_size: 32 }
    }.each do |message, options|
      it "raises when #{message}" do
        expect do
          described_class.new(**options)
        end.to raise_error(BrandLogo::ValidationError, /#{Regexp.escape(message)}/)
      end
    end

    it 'accepts a nil cache' do
      expect(described_class.new(cache: nil).cache).to be_nil
    end

    it 'accepts a custom cache' do
      store = Struct.new(:read, :write).new

      expect(described_class.new(cache: store).cache).to equal(store)
    end

    it 'accepts max_size equal to min_size' do
      expect { described_class.new(min_size: 32, max_size: 32) }.not_to raise_error
    end
  end

  describe '#with' do
    it 'derives a validated variant' do
      derived = config.with(prefer: :largest)

      expect(derived.prefer).to eq(:largest)
      expect(config.prefer).to eq(:square)
    end

    it 'rejects invalid values' do
      expect { config.with(prefer: :nope) }.to raise_error(BrandLogo::ValidationError)
    end
  end

  describe '#cache_digest' do
    it 'is stable for equal settings' do
      expect(config.cache_digest).to eq(described_class.new.cache_digest)
    end

    it 'has 12 hex characters' do
      expect(config.cache_digest).to match(/\A\h{12}\z/)
    end

    {
      min_size: 16, max_size: 256, allow_svg: false, prefer: :largest, target_size: 64,
      color_scheme: :dark, external_fallbacks: [:google], block_private_ips: false
    }.each do |key, value|
      it "changes with #{key}" do
        expect(config.with(key => value).cache_digest).not_to eq(config.cache_digest)
      end
    end

    {
      timeout: 1, deadline: 1, max_hops: 1, max_body_bytes: 1, user_agent: 'x', concurrency: 1,
      cache_ttl: 1, negative_cache_ttl: 1
    }.each do |key, value|
      it "ignores #{key}" do
        expect(config.with(key => value).cache_digest).to eq(config.cache_digest)
      end
    end
  end
end
