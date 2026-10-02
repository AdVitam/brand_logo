# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  skip '/spec/'
  minimum_coverage 95
end

require 'webmock/rspec'
require_relative '../lib/brand_logo'

Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.filter_run_excluding :e2e unless ENV['E2E']
  config.before do |example|
    example.metadata[:e2e] ? WebMock.allow_net_connect! : WebMock.disable_net_connect!
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end
