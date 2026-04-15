# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module BrandLogo
  module Strategies
    # Abstract base class implementing the Template Method pattern.
    #
    # Subclasses implement `fetch_all` (the customization point).
    # `fetch` is the common algorithm: fetch_all → filter valid → select best.
    # This eliminates duplicated selection/validation logic across strategies.
    class BaseStrategy
      extend T::Sig
      extend T::Helpers

      abstract!

      UNKNOWN_DIMENSION_SCORE = T.let(-1, Integer)

      sig { params(config: Config).void }
      def initialize(config:)
        @config = T.let(config, Config)
      end

      # Returns ALL icons found for the domain (unfiltered).
      # Subclasses must implement this method.
      sig { abstract.params(domain: String).returns(T::Array[Icon]) }
      def fetch_all(domain); end

      # Returns the best valid icon for the domain, or nil if none found.
      # Delegates to fetch_all, filters by validity, then selects the best.
      sig { params(domain: String).returns(T.nilable(Icon)) }
      def fetch(domain)
        valid_icons = fetch_all(domain).select { |icon| valid_icon?(icon) }
        select_best_icon(valid_icons)
      end

      protected

      sig { params(icon: Icon).returns(T::Boolean) }
      def valid_icon?(icon)
        valid_dimensions?(icon) && valid_format?(icon)
      end

      private

      sig { params(icon: Icon).returns(T::Boolean) }
      def valid_dimensions?(icon)
        return true if svg_icon?(icon)
        return true if missing_dimensions?(icon)

        meets_minimum_dimensions?(icon) && within_maximum_dimensions?(icon)
      end

      sig { params(icon: Icon).returns(T::Boolean) }
      def valid_format?(icon)
        return true if icon.format != 'svg'

        @config.allow_svg
      end

      sig { params(icons: T::Array[Icon]).returns(T.nilable(Icon)) }
      def select_best_icon(icons)
        return nil if icons.empty?

        if @config.allow_svg
          svg_icon = icons.find { |icon| icon.format == 'svg' }
          return svg_icon if svg_icon
        end

        icons.max_by { |icon| icon_score(icon) }
      end

      sig { params(icon: Icon).returns(Integer) }
      def icon_score(icon)
        width  = icon.dimensions[:width]
        height = icon.dimensions[:height]
        return UNKNOWN_DIMENSION_SCORE if width.nil? || height.nil?

        width * height
      end

      sig { params(icon: Icon).returns(T::Boolean) }
      def svg_icon?(icon)
        @config.allow_svg && icon.format == 'svg'
      end

      sig { params(icon: Icon).returns(T::Boolean) }
      def missing_dimensions?(icon)
        icon.dimensions[:width].nil? || icon.dimensions[:height].nil?
      end

      sig { params(icon: Icon).returns(T::Boolean) }
      def meets_minimum_dimensions?(icon)
        min = @config.min_dimensions
        width  = icon.dimensions[:width]
        height = icon.dimensions[:height]
        return false if width.nil? || height.nil?

        width >= min[:width] && height >= min[:height]
      end

      sig { params(icon: Icon).returns(T::Boolean) }
      def within_maximum_dimensions?(icon)
        max = @config.max_dimensions
        return true if max.nil?

        width  = icon.dimensions[:width]
        height = icon.dimensions[:height]
        return true if width.nil? || height.nil?

        width <= max[:width] && height <= max[:height]
      end
    end
  end
end
