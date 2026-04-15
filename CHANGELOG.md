# Changelog

All notable changes to this project will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
