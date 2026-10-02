# frozen_string_literal: true

RSpec.describe BrandLogo::Strategies::Google do
  subject(:strategy) { described_class.new }

  let(:http) { BrandLogo::FakeHttpClient.new }
  let(:context) { BrandLogo::Context.new(domain: 'github.com', config: BrandLogo::Config.new, http: http) }

  it 'is an external strategy' do
    expect(strategy.stage).to eq(:external)
  end

  it 'returns the unprobed candidate without any request' do
    icon = strategy.call(context).first
    expect(icon).to eq(BrandLogo::Icon.new(url: 'https://www.google.com/s2/favicons?domain=github.com&sz=256',
                                           source: :google))
    expect(http.requests).to be_empty
  end
end
