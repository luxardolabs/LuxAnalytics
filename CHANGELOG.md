# Changelog

All notable changes to LuxAnalytics will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-07-06

### Added
- Initial release of LuxAnalytics for iOS 18+ and Swift 6
- Core analytics tracking with `async/await` API
- DSN-based configuration for simple setup
- Info.plist configuration support
- Event queue with persistent storage
- Smart batching with configurable batch sizes
- Automatic retry logic with exponential backoff
- Circuit breaker pattern for failing endpoints
- Network monitoring with automatic offline queuing
- Compression support with zlib/deflate
- Queue overflow strategies (dropOldest, dropNewest, dropAll)
- Event TTL enforcement
- Debug logging capabilities
- Comprehensive test suite
- Full documentation and examples

### Security
- Secure Basic Authentication via DSN
- Thread-safe singleton implementation
- Optional certificate pinning support
- Automatic PII filtering in logs