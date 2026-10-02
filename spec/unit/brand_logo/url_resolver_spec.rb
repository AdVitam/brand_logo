# frozen_string_literal: true

RSpec.describe BrandLogo::UrlResolver do
  def resolve(href, base = 'https://example.com/fr/')
    described_class.resolve(href, base)
  end

  it 'resolves absolute, protocol-relative, root-relative and path-relative hrefs' do
    expect(resolve('https://cdn.test/a.png')).to eq('https://cdn.test/a.png')
    expect(resolve('//cdn.test/a.png')).to eq('https://cdn.test/a.png')
    expect(resolve('/a.png')).to eq('https://example.com/a.png')
    expect(resolve('favicon.ico')).to eq('https://example.com/fr/favicon.ico')
  end

  it 'returns nil for nil and blank values' do
    expect(resolve(nil)).to be_nil
    expect(resolve('  ')).to be_nil
  end

  it 'strips surrounding whitespace' do
    expect(resolve("  /a.png\n")).to eq('https://example.com/a.png')
  end

  it 'keeps data image URIs as-is' do
    uri = 'data:image/png;base64,AAAA'
    expect(resolve(uri)).to eq(uri)
  end

  it 'rejects non-http schemes and non-image data URIs' do
    %w[javascript:void(0) file:///etc/passwd mailto:a@b.c ftp://example.com/a.png data:text/html,hi].each do |href|
      expect(resolve(href)).to be_nil
    end
  end

  it 'percent-encodes spaces and unicode' do
    expect(resolve('/my logo é.png')).to eq('https://example.com/my%20logo%20%C3%A9.png')
  end

  it 'returns nil when the URL cannot be repaired' do
    expect(resolve('http://[bad')).to be_nil
  end
end
