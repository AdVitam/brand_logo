# frozen_string_literal: true

require 'open3'
require 'rbconfig'

RSpec.describe BrandLogo do
  it 'loads without the test dependencies' do
    lib = File.expand_path('../../lib', __dir__)
    output, status = Open3.capture2e(RbConfig.ruby, '-I', lib, '-e', "require 'brand_logo'\nputs BrandLogo::VERSION")

    expect(status).to be_success, output
    expect(output.strip).to eq(BrandLogo::VERSION)
  end
end
