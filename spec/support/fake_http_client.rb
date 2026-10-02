# frozen_string_literal: true

module BrandLogo
  class FakeHttpClient
    include Http::Client

    attr_reader :requests

    def initialize(responses = {})
      @responses = responses
      @requests = []
      @lock = Mutex.new
    end

    def get(url, max_bytes:, **)
      @lock.synchronize { @requests << url }
      value = @responses[url]
      value = value.call if value.is_a?(Proc)
      case value
      when Http::Response then value
      when String then Http::Response.new(url: url, body: value.byteslice(0, max_bytes).to_s)
      end
    end
  end
end
