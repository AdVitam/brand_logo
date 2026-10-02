# brand_logo

[![Gem Version](https://badge.fury.io/rb/brand_logo.svg)](https://badge.fury.io/rb/brand_logo)
[![Test](https://github.com/AdVitam/brand_logo/actions/workflows/main.yml/badge.svg)](https://github.com/AdVitam/brand_logo/actions/workflows/main.yml)

Fetch the best logo or icon for any website from its domain.

`brand_logo` collects candidates from the page (favicon links, JSON-LD logos, Open Graph /
Twitter / Windows tile meta tags), the PWA manifest and `browserconfig.xml`, then from Google
and DuckDuckGo as a last resort. Every candidate is downloaded once (first 64 KB), its real
format and size are read, dead links and non-images are dropped, and the rest are ranked.

## Installation

```ruby
gem 'brand_logo'
```

## Usage

```ruby
require 'brand_logo'

fetcher = BrandLogo::Fetcher.new

icon = fetcher.fetch('github.com')        # => BrandLogo::Icon or nil
icon.url     # => "https://github.com/fluidicon.png"
icon.format  # => :png
icon.width   # => 512
icon.source  # => :link_tag
icon.kind    # => :icon
icon.to_h    # => { url:, format:, width:, height:, source:, kind:, media: }

fetcher.fetch!('https://github.com/about')  # URLs are accepted; raises NoIconFoundError when nothing is found
fetcher.fetch_all('github.com')             # every valid icon, best first
fetcher.fetch_many(%w[github.com ruby-lang.org]) # => { 'github.com' => Icon, 'ruby-lang.org' => Icon }
```

A `Fetcher` is thread-safe and meant to be reused (it holds the cache).

## How the best icon is chosen

Strategies run in stages; the lookup stops as soon as the best icon so far is good enough
(an SVG, or a raster at least `target_size` — 128 px by default — and square when `prefer: :square`):

| Stage | Strategies | Cost |
|---|---|---|
| document | `LinkTag` (`<link rel="icon" / "apple-touch-icon" / "mask-icon">`, `/favicon.ico`), `JsonLd` (schema.org `Organization#logo`), `MetaTag` (`og:image`, `og:logo`, `twitter:image`, `msapplication-TileImage`) | 1 request for the homepage |
| remote | `Manifest` (PWA `icons[]`), `Browserconfig` (`msapplication-config`) | 1 request each, in parallel |
| external | `Google`, `DuckDuckGo` | only when nothing else is valid |

Ranking: Safari mask icons, monochrome icons and social banners come last; then the `prefer`
setting applies (square icons first by default, SVG over raster, larger first), with optional
`target_size` and `color_scheme` matching on the `media` attribute.

## Configuration

```ruby
config = BrandLogo::Config.new(
  min_size: 32,                        # Integer, { width:, height: } or BrandLogo::Dimensions
  max_size: { width: 1024, height: 1024 },
  allow_svg: true,
  prefer: :square,                     # :square, :largest or :svg
  target_size: 192,                    # pick the icon closest to (and preferably above) this size
  color_scheme: :dark,                 # favour <link media="(prefers-color-scheme: dark)"> icons
  timeout: 5,                          # seconds per request
  deadline: 15,                        # seconds per lookup; the best icon found so far is returned
  max_hops: 5,                         # redirects per request
  max_body_bytes: 2_000_000,
  user_agent: 'MyApp/1.0',
  concurrency: 4,                      # parallel probes and fetch_many lookups
  block_private_ips: true,             # SSRF protection, see below
  external_fallbacks: %i[google duckduckgo], # [] to never contact third parties
  cache: Rails.cache,                  # anything with read(key) / write(key, value, expires_in:); nil disables
  cache_ttl: 86_400,
  negative_cache_ttl: 3_600
)

fetcher = BrandLogo::Fetcher.new(config: config)
other = BrandLogo::Fetcher.new(config: config.with(prefer: :largest))
```

Invalid settings raise `BrandLogo::ValidationError`. The default cache is an in-memory store
per `Fetcher`. Lookups that hit the deadline without a result are not cached.

### Custom strategies

```ruby
class MyStrategy
  include BrandLogo::Strategies::Base

  def stage = :document

  def call(context)
    page = context.page or return []
    url = page.resolve(page.document.at('img.logo')&.[]('src')) or return []
    [BrandLogo::Icon.new(url: url, source: :my_strategy, kind: :logo)]
  end
end

BrandLogo::Fetcher.new(strategies: [MyStrategy.new, BrandLogo::Strategies::LinkTag.new])
```

## Input

`fetch` accepts a hostname or a URL (`"GitHub.com "`, `"https://github.com/about"`).
Internationalized domains must be given in punycode (`xn--…`); IP addresses are rejected.

## Security

The gem fetches URLs chosen by third-party pages. With `block_private_ips: true` (default),
every request — including each redirect — is refused unless its host resolves only to public
addresses, and only `http`/`https` URLs are fetched. A DNS answer that changes between the check
and the connection (DNS rebinding) is not covered; run lookups from a network without access to
sensitive internal services if inputs are untrusted.

## Logging

```ruby
BrandLogo::Logging.logger.level = Logger::DEBUG
BrandLogo::Logging.logger = Rails.logger
```

## Sorbet

The gem is typed with Sorbet but does not depend on `sorbet-runtime`: signatures are checked
statically in CI, and at runtime the gem uses `sorbet-runtime` only if your bundle already has it.

## Requirements

- Ruby >= 3.2

## Contributing

Bug reports and pull requests are welcome on GitHub at
<https://github.com/AdVitam/brand_logo>.

```bash
bundle exec rspec
bundle exec rubocop
bundle exec srb tc
E2E=1 bundle exec rspec --tag e2e   # hits real websites
```

## License

Released under the MIT License. See [LICENSE.txt](LICENSE.txt).
