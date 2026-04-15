# frozen_string_literal: true

require_relative 'lib/brand_logo/version'

Gem::Specification.new do |spec|
  spec.name     = 'brand_logo'
  spec.version  = BrandLogo::VERSION
  spec.authors  = ['Philippe Meyralbe', 'AdVitam']
  spec.email    = ['philippe.meyralbe@advitam.fr']

  spec.summary     = 'Fetch the best logo or icon for any website from its domain'
  spec.description = 'Retrieves brand logos and icons from websites using a chain of strategies: ' \
                     'HTML favicon tags, Open Graph / Twitter meta images, PWA web app manifests, ' \
                     'and a DuckDuckGo fallback. Returns the best icon based on format and dimensions.'
  spec.homepage    = 'https://github.com/AdVitam/brand_logo'
  spec.license     = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata = {
    'rubygems_mfa_required' => 'true',
    'homepage_uri'     => spec.homepage,
    'source_code_uri'  => spec.homepage,
    'changelog_uri'    => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'bug_tracker_uri'  => "#{spec.homepage}/issues"
  }

  spec.files = Dir['lib/**/*', 'LICENSE.txt', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'fastimage',      '~> 2.4'
  spec.add_dependency 'http',           '>= 5.2'
  spec.add_dependency 'logger',         '~> 1.6'
  spec.add_dependency 'nokogiri',       '>= 1.18'
  spec.add_dependency 'sorbet-runtime', '>= 0.5'
end
