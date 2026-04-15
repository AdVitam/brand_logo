# frozen_string_literal: true

RSpec.describe BrandLogo::Logging do
  describe '.logger' do
    it 'returns a Logger instance by default' do
      expect(described_class.logger).to be_a(::Logger)
    end
  end

  describe '.logger=' do
    after { described_class.logger = ::Logger.new($stderr, level: ::Logger::WARN) }

    it 'replaces the logger' do
      custom = ::Logger.new($stdout)
      described_class.logger = custom
      expect(described_class.logger).to eq(custom)
    end
  end
end
