# frozen_string_literal: true
# typed: strict

require 'uri'

module BrandLogo
  class Context
    extend T::Sig

    sig { returns(String) }
    attr_reader :domain

    sig { returns(Config) }
    attr_reader :config

    sig { returns(Deadline) }
    attr_reader :deadline

    sig { params(domain: String, config: Config, http: Http::Client, deadline: T.nilable(Deadline)).void }
    def initialize(domain:, config:, http:, deadline: nil)
      @domain = domain
      @config = config
      @http = http
      @deadline = T.let(deadline || Deadline.new(config.deadline), Deadline)
      @lock = T.let(Mutex.new, Mutex)
      @page = T.let(nil, T.nilable(Page))
      @page_loaded = T.let(false, T::Boolean)
      @probes = T.let({}, T::Hash[String, T.nilable(ImageProbe::Result)])
    end

    sig { params(url: String, max_bytes: T.nilable(Integer), range: T.nilable(T::Range[Integer])).returns(T.nilable(Http::Response)) }
    def get(url, max_bytes: nil, range: nil)
      @http.get(url, deadline: @deadline, max_bytes: max_bytes || @config.max_body_bytes, range: range)
    end

    sig { returns(T.nilable(Page)) }
    def page
      @lock.synchronize do
        unless @page_loaded
          @page = Page.fetch(self)
          @page_loaded = true
        end
        @page
      end
    end

    sig { params(url: String).returns(T.nilable(ImageProbe::Result)) }
    def probe(url)
      return @probes[url] if @lock.synchronize { @probes.key?(url) }

      body = url.start_with?('data:') ? decode_data_uri(url) : get(url, max_bytes: ImageProbe::BYTES, range: 0...ImageProbe::BYTES)&.body
      result = body && ImageProbe.analyze(body)
      @lock.synchronize { @probes[url] = result }
    end

    private

    sig { params(url: String).returns(T.nilable(String)) }
    def decode_data_uri(url)
      header, payload = url.split(',', 2)
      return nil unless header && payload

      header.end_with?(';base64') ? payload.unpack1('m') : URI.decode_www_form_component(payload)
    rescue ArgumentError
      nil
    end
  end
end
