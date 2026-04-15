# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

# Foundation
require_relative 'brand_logo/version'
require_relative 'brand_logo/errors'
require_relative 'brand_logo/config'
require_relative 'brand_logo/logging'

# Interfaces & implementations
require_relative 'brand_logo/http_client'
require_relative 'brand_logo/image_analyzer'
require_relative 'brand_logo/html_parser'

# Domain model
require_relative 'brand_logo/icon'

# Strategies — base must be loaded before subclasses
require_relative 'brand_logo/strategies/base_strategy'

# Scraping utilities (loaded before strategies that use them)
require_relative 'brand_logo/strategies/scraping/format_extractor'
require_relative 'brand_logo/strategies/scraping/url_normalizer'
require_relative 'brand_logo/strategies/scraping/dimensions_extractor'
require_relative 'brand_logo/strategies/scraping/default_favicon_checker'
require_relative 'brand_logo/strategies/scraping/icon_finder'

# Concrete strategies
require_relative 'brand_logo/strategies/scraping_strategy'
require_relative 'brand_logo/strategies/duckduckgo_strategy'
require_relative 'brand_logo/strategies/meta_tag_strategy'
require_relative 'brand_logo/strategies/manifest_strategy'

# Entry point
require_relative 'brand_logo/fetcher'
