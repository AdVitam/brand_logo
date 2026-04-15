# frozen_string_literal: true

module BrandLogo
  # Test double for ImageAnalyzer — returns fixed dimensions without network calls.
  #
  # Usage:
  #   analyzer = FakeImageAnalyzer.new(default: { width: 32, height: 32 })
  #   analyzer = FakeImageAnalyzer.new(responses: { 'https://example.com/icon.png' => { width: 64, height: 64 } })
  class FakeImageAnalyzer
    include ImageAnalyzer

    def initialize(default: { width: nil, height: nil }, responses: {})
      @default   = default
      @responses = responses
    end

    def dimensions(url)
      @responses.fetch(url, @default)
    end
  end
end
