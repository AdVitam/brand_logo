# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'
require 'nokogiri'

module BrandLogo
  # Value Object wrapping a parsed HTML document.
  # Exposes only the subset of the Nokogiri API that strategies need,
  # preventing strategies from depending on Nokogiri directly.
  class ParsedDocument
    extend T::Sig

    sig { params(doc: Nokogiri::HTML::Document).void }
    def initialize(doc)
      @doc = T.let(doc, Nokogiri::HTML::Document)
    end

    # Returns all elements matching the CSS selector.
    sig { params(selector: String).returns(T::Array[T.untyped]) }
    def css(selector)
      @doc.css(selector).to_a
    end

    # Returns the first element matching the CSS selector, or nil.
    sig { params(selector: String).returns(T.untyped) }
    def at(selector)
      @doc.at(selector)
    end

    # Returns the href of the <base> tag if present.
    sig { returns(T.nilable(String)) }
    def base_href
      node = @doc.at('base')
      return nil unless node

      node['href']
    end
  end

  # Interface for parsing raw HTML into a ParsedDocument.
  # Strategies receive this via dependency injection.
  module HtmlParser
    extend T::Sig
    extend T::Helpers
    interface!

    sig { abstract.params(html: String).returns(ParsedDocument) }
    def parse(html); end
  end

  # Concrete implementation using the Nokogiri gem.
  class NokogiriParser
    extend T::Sig
    include HtmlParser

    sig { override.params(html: String).returns(ParsedDocument) }
    def parse(html)
      ParsedDocument.new(Nokogiri::HTML(html))
    end
  end
end
