# brand_logo

[![Gem Version](https://badge.fury.io/rb/brand_logo.svg)](https://badge.fury.io/rb/brand_logo)
[![Test](https://github.com/AdVitam/brand_logo/actions/workflows/main.yml/badge.svg)](https://github.com/AdVitam/brand_logo/actions/workflows/main.yml)

**Give it a domain, get back the best logo that site has to offer.**

```ruby
BrandLogo::Fetcher.new.fetch('github.com').url # => "https://github.com/fluidicon.png"
```

Perfect for company directories, CRM enrichment, link previews or any list of brands that
deserves real logos instead of blurry 16 px favicons.

- **The right icon, not the first one** — favicon links, `apple-touch-icon`, schema.org JSON-LD
  logos, Open Graph tags, PWA manifest and `browserconfig.xml` are compared by their *real*
  size and format. Square, crisp and SVG wins; Safari mask icons and social banners lose.
- **Fast** — one homepage request, image probes run in parallel and read 64 KB at most,
  the lookup stops as soon as a good icon is found, and results are cached (`Rails.cache` ready).
- **Never empty-handed** — Google and DuckDuckGo favicon services as a last resort.
- **Safe on untrusted input** — SSRF protection on every redirect, bounded timeouts and body sizes.
- **Tunable** — prefer square, largest or SVG, target a size, pick dark-mode icons.
- **Light** — no `sorbet-runtime` dependency, thread-safe, batch lookups with `fetch_many`.

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
