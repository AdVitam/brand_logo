# frozen_string_literal: true

module BrandLogo
  # Test double for HttpClient — returns responses from a predefined Hash.
  # Fully implements the HttpClient interface without making network calls.
  #
  # Usage:
  #   client = FakeHttpClient.new(
  #     'https://example.com' => '<html>...</html>',  # get_body returns the string
  #     'https://example.com/favicon.ico' => :head_ok  # head_success? returns true
  #   )
  class FakeHttpClient
    include HttpClient

    # :head_ok       → head_success? returns true, get_body returns nil
    # String         → get_body returns the string, head_success? returns true
    # nil / missing  → both return falsy
    def initialize(responses = {})
      @responses = responses
    end

    def get_body(url)
      resp = @responses[url]
      resp.is_a?(String) ? resp : nil
    end

    def head_success?(url)
      resp = @responses[url]
      resp == :head_ok || resp.is_a?(String)
    end
  end
end
