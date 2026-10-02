# frozen_string_literal: true
# typed: strict

module BrandLogo
  class Ranker
    extend T::Sig

    KIND_TIERS = T.let({
      mask: 3, monochrome: 3, social: 2, tile: 1
    }.freeze, T::Hash[Symbol, Integer])
    UNUSABLE_KINDS = T.let(%i[mask monochrome social].freeze, T::Array[Symbol])
    DEFAULT_GOOD_SIZE = 128
    MAX_ASPECT_RATIO = 1.2

    sig { params(config: Config).void }
    def initialize(config)
      @config = config
    end

    sig { params(icons: T::Array[Icon]).returns(T::Array[Icon]) }
    def rank(icons)
      icons.select { |icon| valid?(icon) }
           .each_with_index
           .sort_by { |icon, index| [*penalty(icon), index] }
           .map(&:first)
    end

    sig { params(icon: Icon).returns(T::Boolean) }
    def usable?(icon)
      valid?(icon) && !UNUSABLE_KINDS.include?(icon.kind)
    end

    sig { params(icon: Icon).returns(T::Boolean) }
    def good_enough?(icon)
      return false unless usable?(icon)
      return false if @config.prefer == :square && non_square?(icon)

      icon.svg? || icon.dimensions.side >= (@config.target_size || DEFAULT_GOOD_SIZE)
    end

    private

    sig { params(icon: Icon).returns(T::Boolean) }
    def valid?(icon)
      return false if icon.format.nil?
      return @config.allow_svg if icon.svg?

      within_limits?(icon.dimensions)
    end

    sig { params(dims: Dimensions).returns(T::Boolean) }
    def within_limits?(dims)
      min = @config.min_size
      max = @config.max_size
      (min.nil? || dims.at_least?(min)) && (max.nil? || dims.at_most?(max))
    end

    sig { params(icon: Icon).returns(T::Array[Numeric]) }
    def penalty(icon)
      [KIND_TIERS.fetch(icon.kind, 0), scheme_penalty(icon), *preference_penalty(icon), *size_penalty(icon)]
    end

    sig { params(icon: Icon).returns(Integer) }
    def scheme_penalty(icon)
      wanted = @config.color_scheme
      return dark_media?(icon) ? 1 : 0 unless wanted

      opposite = wanted == :dark ? :light : :dark
      return 0 if media_mentions?(icon, wanted)

      media_mentions?(icon, opposite) ? 2 : 1
    end

    sig { params(icon: Icon).returns(T::Boolean) }
    def dark_media?(icon)
      media_mentions?(icon, :dark)
    end

    sig { params(icon: Icon, scheme: Symbol).returns(T::Boolean) }
    def media_mentions?(icon, scheme)
      /prefers-color-scheme\s*:\s*#{scheme}/i.match?(icon.media.to_s)
    end

    sig { params(icon: Icon).returns(T::Array[Integer]) }
    def preference_penalty(icon)
      case @config.prefer
      when :svg then [icon.svg? ? 0 : 1]
      when :square then [non_square?(icon) ? 1 : 0, icon.svg? ? 0 : 1]
      else []
      end
    end

    sig { params(icon: Icon).returns(T::Boolean) }
    def non_square?(icon)
      w, h = icon.dimensions.to_pair
      return false unless w && h

      [w, h].max.fdiv([w, h].min) > MAX_ASPECT_RATIO
    end

    sig { params(icon: Icon).returns(T::Array[Numeric]) }
    def size_penalty(icon)
      target = @config.target_size
      return [-area(icon)] unless target

      side = icon.svg? ? target : icon.dimensions.side
      return [0, target / 2.0, -area(icon)] if side.zero?

      [side < target ? 1 : 0, (side - target).abs, -area(icon)]
    end

    sig { params(icon: Icon).returns(Numeric) }
    def area(icon)
      icon.svg? ? Float::INFINITY : icon.dimensions.area
    end
  end
end
