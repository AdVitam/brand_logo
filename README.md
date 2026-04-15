# brand_logo

[![Gem Version](https://badge.fury.io/rb/brand_logo.svg)](https://badge.fury.io/rb/brand_logo)
[![Test](https://github.com/AdVitam/brand_logo/actions/workflows/main.yml/badge.svg)](https://github.com/AdVitam/brand_logo/actions/workflows/main.yml)

Fetch the best logo or icon for any website from its domain.

`brand_logo` chains several strategies (favicon tags, Open Graph / Twitter meta
images, PWA web app manifests, DuckDuckGo fallback) and returns the best icon
based on format and dimensions.

## Installation

```ruby
gem 'brand_logo'
```

## Usage

```ruby
require 'brand_logo'

fetcher = BrandLogo::Fetcher.new
icon = fetcher.fetch('github.com')

icon.url        # => "https://github.com/favicon.svg"
icon.format     # => "svg"
icon.dimensions # => { width: nil, height: nil }
```

### All icons

```ruby
icons = fetcher.fetch_all('github.com')
# Every icon found across all strategies, deduplicated by URL
```

### Configuration

```ruby
config = BrandLogo::Config.new(
  min_dimensions: { width: 32, height: 32 },   # ignore tiny icons
  max_dimensions: { width: 512, height: 512 }, # ignore oversized images
  allow_svg:      true,                        # prefer SVG when available
  timeout:        10,                          # HTTP timeout in seconds
  max_hops:       5                            # max redirects to follow
)

fetcher = BrandLogo::Fetcher.new(config: config)
```

### Custom strategy chain

Strategies are tried in order until one succeeds:

```ruby
fetcher = BrandLogo::Fetcher.new(
  strategies: [
    BrandLogo::Strategies::ScrapingStrategy.new(config: config, ...),
    BrandLogo::Strategies::DuckduckgoStrategy.new(config: config, ...)
  ]
)
```

Default chain: `ScrapingStrategy → MetaTagStrategy → ManifestStrategy → DuckduckgoStrategy`

### Logging

```ruby
require 'logger'
BrandLogo::Logging.logger.level = Logger::DEBUG  # verbose output
BrandLogo::Logging.logger = MyCustomLogger.new   # inject your own logger
```

## Strategies

| Strategy | Source | Notes |
|---|---|---|
| `ScrapingStrategy` | HTML `<link rel="icon">` tags | Primary — tries `https://`, `https://www.`, `http://` |
| `MetaTagStrategy` | `og:image`, `twitter:image` | High-res images, filter via `max_dimensions` |
| `ManifestStrategy` | PWA `manifest.json` `icons[]` | Best for progressive web apps |
| `DuckduckgoStrategy` | DuckDuckGo icon cache | Last-resort fallback |

## Error handling

```ruby
begin
  icon = fetcher.fetch('example.com')
rescue BrandLogo::NoIconFoundError
  # no icon found by any strategy
rescue BrandLogo::ValidationError => e
  # invalid domain format: e.message
end
```

## Requirements

- Ruby >= 3.2

## Contributing

Bug reports and pull requests are welcome on GitHub at
<https://github.com/AdVitam/brand_logo>.

## License

Released under the MIT License. See [LICENSE.txt](LICENSE.txt).
