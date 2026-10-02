# frozen_string_literal: true

RSpec.describe BrandLogo::Ranker do
  def icon(url, format: :png, size: nil, kind: :icon, media: nil)
    dims = size ? BrandLogo::Dimensions.new(width: size.first, height: size.last) : BrandLogo::Dimensions.new
    BrandLogo::Icon.new(url: url, source: :link_tag, format: format, dimensions: dims, kind: kind, media: media)
  end

  def rank(icons, **options)
    described_class.new(BrandLogo::Config.new(**options)).rank(icons).map(&:url)
  end

  describe '#rank' do
    it 'drops icons without a probed format' do
      expect(rank([icon('a', format: nil, size: [64, 64]), icon('b', size: [32, 32])])).to eq(['b'])
    end

    it 'drops SVG unless allowed' do
      icons = [icon('s', format: :svg), icon('p', size: [32, 32])]
      expect(rank(icons, allow_svg: false)).to eq(['p'])
      expect(rank(icons)).to eq(%w[s p])
    end

    it 'applies size limits to rasters with known dimensions only' do
      icons = [icon('small', size: [16, 16]), icon('ok', size: [64, 64]), icon('big', size: [512, 512]),
               icon('unknown'), icon('svg', format: :svg)]
      expect(rank(icons, min_size: 32, max_size: 256)).to eq(%w[svg ok unknown])
    end

    it 'prefers square icons, then SVG, then size' do
      icons = [icon('wide', size: [512, 128]), icon('small', size: [32, 32]), icon('big', size: [64, 64]),
               icon('svg', format: :svg)]
      expect(rank(icons)).to eq(%w[svg big small wide])
    end

    it 'ranks masks, monochrome and social images after regular icons' do
      icons = [icon('mask', kind: :mask, size: [512, 512]), icon('og', kind: :social, size: [1200, 630]),
               icon('mono', kind: :monochrome, size: [512, 512]), icon('tile', kind: :tile, size: [270, 270]),
               icon('ico', size: [16, 16])]
      expect(rank(icons)).to eq(%w[ico tile og mask mono])
    end

    it 'ranks a wide SVG wordmark after square rasters' do
      icons = [icon('wordmark', format: :svg, size: [304, 86]), icon('png', size: [120, 120])]
      expect(rank(icons)).to eq(%w[png wordmark])
    end

    it 'prefers SVG then size with prefer: :svg' do
      icons = [icon('wide', size: [512, 128]), icon('png', size: [64, 64]), icon('svg', format: :svg)]
      expect(rank(icons, prefer: :svg)).to eq(%w[svg wide png])
    end

    it 'prefers the largest area with prefer: :largest' do
      icons = [icon('png', size: [512, 512]), icon('wide', size: [1024, 256]), icon('svg', format: :svg)]
      expect(rank(icons, prefer: :largest)).to eq(%w[svg png wide])
    end

    it 'prefers the closest size at or above target_size' do
      icons = [icon('s', size: [64, 64]), icon('xl', size: [512, 512]), icon('m', size: [160, 160]),
               icon('unknown')]
      expect(rank(icons, target_size: 128)).to eq(%w[m unknown xl s])
    end

    it 'favors the requested color scheme and penalizes the opposite one' do
      icons = [icon('dark', size: [64, 64], media: '(prefers-color-scheme: dark)'), icon('plain', size: [64, 64]),
               icon('light', size: [64, 64], media: '(prefers-color-scheme: light)')]
      expect(rank(icons, color_scheme: :dark)).to eq(%w[dark plain light])
      expect(rank(icons, color_scheme: :light)).to eq(%w[light plain dark])
    end

    it 'penalizes dark icons when no color scheme is requested' do
      icons = [icon('dark', size: [128, 128], media: '(prefers-color-scheme: dark)'), icon('plain', size: [64, 64])]
      expect(rank(icons)).to eq(%w[plain dark])
    end

    it 'keeps input order on ties' do
      icons = [icon('a', size: [64, 64]), icon('b', size: [64, 64]), icon('c', size: [64, 64])]
      expect(rank(icons)).to eq(%w[a b c])
    end
  end

  describe '#good_enough?' do
    subject(:ranker) { described_class.new(BrandLogo::Config.new(**options)) }

    let(:options) { {} }

    it 'accepts SVG and rasters of at least 128px' do
      expect(ranker.good_enough?(icon('s', format: :svg))).to be(true)
      expect(ranker.good_enough?(icon('p', size: [128, 128]))).to be(true)
    end

    it 'rejects small, unmeasured, masked, monochrome and social icons' do
      expect(ranker.good_enough?(icon('p', size: [64, 64]))).to be(false)
      expect(ranker.good_enough?(icon('p'))).to be(false)
      expect(ranker.good_enough?(icon('m', kind: :mask, size: [512, 512]))).to be(false)
      expect(ranker.good_enough?(icon('m', kind: :monochrome, format: :svg))).to be(false)
      expect(ranker.good_enough?(icon('o', kind: :social, size: [1200, 1200]))).to be(false)
    end

    it 'rejects a wide SVG unless square is not preferred' do
      wordmark = icon('w', format: :svg, size: [304, 86])
      expect(ranker.good_enough?(wordmark)).to be(false)
      expect(described_class.new(BrandLogo::Config.new(prefer: :svg)).good_enough?(wordmark)).to be(true)
    end

    it 'rejects SVG when not allowed' do
      expect(described_class.new(BrandLogo::Config.new(allow_svg: false)).good_enough?(icon('s',
                                                                                            format: :svg))).to be(false)
    end

    context 'with a target_size' do
      let(:options) { { target_size: 256 } }

      it 'requires that size' do
        expect(ranker.good_enough?(icon('p', size: [128, 128]))).to be(false)
        expect(ranker.good_enough?(icon('p', size: [256, 256]))).to be(true)
      end
    end
  end
end
