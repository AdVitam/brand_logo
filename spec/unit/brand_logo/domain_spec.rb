# frozen_string_literal: true

RSpec.describe BrandLogo::Domain do
  describe '.normalize' do
    {
      'github.com' => 'github.com',
      ' GitHub.com ' => 'github.com',
      'https://github.com' => 'github.com',
      'https://User@GitHub.com:8443/about?x=1#y' => 'github.com',
      '//github.com/about' => 'github.com',
      'github.com/about' => 'github.com',
      'github.com:443' => 'github.com',
      'github.com.' => 'github.com',
      'sub.domain.co.uk' => 'sub.domain.co.uk',
      'xn--80ak6aa92e.xn--p1ai' => 'xn--80ak6aa92e.xn--p1ai'
    }.each do |input, expected|
      it "normalizes #{input.inspect} to #{expected.inspect}" do
        expect(described_class.normalize(input)).to eq(expected)
      end
    end

    ['', '   ', 'https://', 'localhost', '192.168.1.1', 'http://127.0.0.1/x', '[::1]', '::1', 'http://[::1]:80/',
     '-a.com', 'a-.com', '..com', 'a..com', 'a b.com', 'under_score.com', 'example.c', 'example.123',
     "#{'a' * 64}.com", "#{(['a' * 60] * 5).join('.')}.com", 'http://exa mple.com'].each do |input|
      it "rejects #{input.inspect}" do
        expect { described_class.normalize(input) }.to raise_error(BrandLogo::ValidationError)
      end
    end

    it 'suggests punycode for non-ASCII input' do
      expect { described_class.normalize('café.fr') }.to raise_error(BrandLogo::ValidationError, /punycode/)
    end
  end
end
