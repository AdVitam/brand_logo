# frozen_string_literal: true
# typed: strict

require_relative 'brand_logo/sorbet'

require_relative 'brand_logo/version'
require_relative 'brand_logo/errors'
require_relative 'brand_logo/logging'
require_relative 'brand_logo/concurrency'
require_relative 'brand_logo/cache'
require_relative 'brand_logo/dimensions'
require_relative 'brand_logo/image_format'
require_relative 'brand_logo/icon'
require_relative 'brand_logo/config'
require_relative 'brand_logo/deadline'
require_relative 'brand_logo/domain'

require_relative 'brand_logo/http/response'
require_relative 'brand_logo/http/client'
require_relative 'brand_logo/http/url_guard'
require_relative 'brand_logo/http/real_client'

require_relative 'brand_logo/lenient_json'
require_relative 'brand_logo/url_resolver'
require_relative 'brand_logo/image_probe'
require_relative 'brand_logo/page'
require_relative 'brand_logo/context'
require_relative 'brand_logo/ranker'

require_relative 'brand_logo/strategies/base'
require_relative 'brand_logo/strategies/link_tag'
require_relative 'brand_logo/strategies/json_ld'
require_relative 'brand_logo/strategies/meta_tag'
require_relative 'brand_logo/strategies/manifest'
require_relative 'brand_logo/strategies/browserconfig'
require_relative 'brand_logo/strategies/google'
require_relative 'brand_logo/strategies/duckduckgo'

require_relative 'brand_logo/lookup'
require_relative 'brand_logo/fetcher'
