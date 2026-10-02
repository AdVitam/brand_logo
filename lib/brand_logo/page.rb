# frozen_string_literal: true
# typed: strict

require 'nokogiri'

module BrandLogo
  Page = Data.define(:url, :document, :base_url) do
    extend T::Sig

    sig { params(context: Context).returns(T.nilable(Page)) }
    def self.fetch(context)
      domain = context.domain
      ["https://#{domain}", "https://www.#{domain}", "http://#{domain}"].each do |candidate|
        response = context.get(candidate)
        return build(response) if response
      end
      nil
    end

    sig { params(response: Http::Response).returns(T.nilable(Page)) }
    def self.build(response)
      document = Nokogiri::HTML5(response.body)
      declared = document.at_css('base[href]')&.[]('href')
      base_url = UrlResolver.resolve(declared, response.url) || response.url
      new(url: response.url, document: document, base_url: base_url)
    rescue ArgumentError => e
      Logging.logger.warn("Page: cannot parse #{response.url}: #{e.message}")
      nil
    end
    private_class_method :build

    sig { params(href: T.nilable(String)).returns(T.nilable(String)) }
    def resolve(href)
      UrlResolver.resolve(href, base_url)
    end
  end
end
