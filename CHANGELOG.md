# Changelog

All notable changes to this project will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.0.1] - 2026-10-09

### Fixed

- JSON-LD and web app manifests containing duplicated keys or comments are parsed again with `json` 3, which rejects them by default.

### Changed

- CI tests the minimum supported dependency versions (`gemfiles/minimum.gemfile`, Ruby 3.2) and Dependabot is enabled.
- Gem metadata: removed the `homepage_uri` duplicate of `source_code_uri`.

## [2.0.0] - 2026-10-02

Rewrite focused on picking the right icon, speed and safety. Breaking changes: see *Upgrading*.

### Added

- `JsonLd` strategy: schema.org `Organization` / `Brand` logos (including `@graph` and `ImageObject`).
- `Browserconfig` strategy (`msapplication-config`) and `msapplication-TileImage` / `og:logo` meta tags.
- `Google` favicon service fallback, before DuckDuckGo; both can be disabled with `external_fallbacks: []`.
- `Fetcher#fetch!`, `Fetcher#fetch_many` (concurrent), URL input (`fetch('https://github.com/about')`).
- Caching: in-memory by default, or any `read`/`write(expires_in:)` store such as `Rails.cache`; misses use `negative_cache_ttl`.
- Ranking options: `prefer` (`:square`, `:largest`, `:svg`), `target_size`, `color_scheme` (`media` attribute).
- `deadline` (total time per lookup), `user_agent`, `max_body_bytes`, `concurrency`, `block_private_ips`.
- `Icon#source`, `#kind`, `#media`, `#width`, `#height`, `#to_h`, `Icon.from_h`.

### Changed

- `fetch` returns the best icon across strategies (stopping early once one is good enough) instead of the first strategy's result.
- Every candidate is probed: dead links, HTML soft-404s and non-images are dropped; the format comes from the image bytes.
- The homepage is fetched once per lookup (was up to 7 times); probes are deduplicated, run in parallel and read 64 KB at most.
- Safari mask icons, monochrome icons and social banners rank last; PWA manifest icons beat `og:image`.
- Redirects are followed for every request and the final URL (or `<base href>`) is used to resolve relative links.
- Requests send a browser-like `User-Agent`; `timeout` is now a total per request (default 5 s).
- `sizes="16x16 32x32"`, uppercase `X` and query strings (`/icon.png?v=2`) are understood.
- Domain validation accepts URLs and mixed case, rejects malformed labels (`-a.com`, `..com`).
- `sorbet-runtime` is no longer a runtime dependency; `http` and `nokogiri` versions are bounded.

### Security

- SSRF protection (`block_private_ips`, on by default): private, loopback and link-local addresses are refused at every redirect; only `http`/`https` URLs are fetched.

### Removed

- `ScrapingStrategy` (now `LinkTag`), `MetaTagStrategy`, `ManifestStrategy`, `DuckduckgoStrategy` (now `Strategies::MetaTag`, `Manifest`, `Duckduckgo`).
- `HttpClient`, `HtmlParser`, `ImageAnalyzer` interfaces: inject a `BrandLogo::Http::Client` instead.
- `FetchError`, `ParseError`.

### Upgrading from 1.x

| 1.x | 2.0 |
|---|---|
| `fetch(domain)` raises `NoIconFoundError` | `fetch` returns `nil`; use `fetch!` to raise |
| `icon.dimensions[:width]` | `icon.width` (or `icon.dimensions.width`) |
| `icon.format == 'svg'` | `icon.format == :svg` |
| `Config.new(min_dimensions: { width: 32, height: 32 })` | `Config.new(min_size: 32)` |
| `max_dimensions:` | `max_size:` |
| `Fetcher.new(strategies: [ScrapingStrategy.new(config:, http_client:, …)])` | `Fetcher.new(strategies: [Strategies::LinkTag.new])` |
| custom strategy: subclass `BaseStrategy`, implement `fetch_all(domain)` | `include Strategies::Base`, implement `stage` and `call(context)` |

## [1.0.1] - 2026-07-23

### Changed

- Publish to RubyGems via trusted publishing (OIDC) instead of a long-lived API key
- Bump simplecov to 1.0.0, migrate `add_filter` to `skip`

## [1.0.0] - 2026-04-15

First public release under the name `brand_logo`.

### Added

- `BrandLogo::Fetcher` entry point — accepts `config:` and `strategies:` keyword
  arguments.
- `fetch_all(domain)` on `Fetcher` — returns every icon found across all
  strategies, deduplicated by URL.
- **Four strategies**, tried in order:
  - `ScrapingStrategy` — parses HTML `<link rel="icon">` tags, retries with
    `https://www.` prefix and `http://` fallback.
  - `MetaTagStrategy` — reads `og:image`, `twitter:image` meta tags.
  - `ManifestStrategy` — parses PWA `manifest.json` `icons[]` entries.
  - `DuckduckgoStrategy` — last-resort DuckDuckGo icon cache fallback.
- `BrandLogo::Config` — centralises `min_dimensions`, `max_dimensions`,
  `allow_svg`, `timeout`, `max_hops`.
- `BrandLogo::Logging` — configurable via any stdlib `Logger`.
- Typed error hierarchy: `FetchError`, `NoIconFoundError`, `ValidationError`,
  `ParseError`.
- Domain validation in `Fetcher#fetch` — raises `ValidationError` for invalid input.
- Configurable HTTP timeout (default 10 s).
- Dependency injection for `HttpClient`, `HtmlParser`, `ImageAnalyzer` — strategies are
  fully testable without network calls.
- Sorbet `typed: strict` everywhere.
- RSpec test suite with **100% line coverage** (SimpleCov).
