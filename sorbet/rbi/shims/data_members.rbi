# typed: strict

# Sorbet types Data.define members as T.untyped; these declare their real types.

module BrandLogo
  class Dimensions
    sig { returns(T.nilable(Integer)) }
    def width; end

    sig { returns(T.nilable(Integer)) }
    def height; end
  end

  class Icon
    sig { returns(String) }
    def url; end

    sig { returns(T.nilable(Symbol)) }
    def format; end

    sig { returns(Dimensions) }
    def dimensions; end

    sig { returns(Symbol) }
    def source; end

    sig { returns(Symbol) }
    def kind; end

    sig { returns(T.nilable(String)) }
    def media; end
  end

  class Config
    sig { returns(T.nilable(Dimensions)) }
    def min_size; end

    sig { returns(T.nilable(Dimensions)) }
    def max_size; end

    sig { returns(T::Boolean) }
    def allow_svg; end

    sig { returns(Symbol) }
    def prefer; end

    sig { returns(T.nilable(Integer)) }
    def target_size; end

    sig { returns(T.nilable(Symbol)) }
    def color_scheme; end

    sig { returns(Numeric) }
    def timeout; end

    sig { returns(Numeric) }
    def deadline; end

    sig { returns(Integer) }
    def max_hops; end

    sig { returns(Integer) }
    def max_body_bytes; end

    sig { returns(String) }
    def user_agent; end

    sig { returns(Integer) }
    def concurrency; end

    sig { returns(T::Boolean) }
    def block_private_ips; end

    sig { returns(T::Array[Symbol]) }
    def external_fallbacks; end

    sig { returns(T.untyped) }
    def cache; end

    sig { returns(Integer) }
    def cache_ttl; end

    sig { returns(Integer) }
    def negative_cache_ttl; end
  end

  class Page
    sig { returns(String) }
    def url; end

    sig { returns(Nokogiri::HTML5::Document) }
    def document; end

    sig { returns(String) }
    def base_url; end
  end

  module ImageProbe
    class Result
      sig { returns(Symbol) }
      def format; end

      sig { returns(Dimensions) }
      def dimensions; end
    end
  end

  module Http
    class Response
      sig { returns(String) }
      def url; end

      sig { returns(String) }
      def body; end
    end
  end
end
