# Changelog

All notable changes to LuxAnalytics will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-07-13

### 🎉 Initial Release

LuxAnalytics v1.0.0 is the first public release of our privacy-first analytics SDK for iOS 18+, built exclusively with Swift 6 and modern concurrency patterns. This release achieves **zero compilation warnings** with full iOS 18 and Swift 6 strict concurrency compliance.

### Added

#### Core Features
- **100% Async/Await API** - All public APIs use modern Swift concurrency
- **Actor-based Architecture** - Thread-safe by design with full actor isolation
- **DSN-based Configuration** - Simple setup with `https://publicId@domain.com/api/v1/events/projectId`
- **Automatic Event Batching** - Smart batching with configurable batch sizes (default: 50 events)
- **Persistent Queue** - Events survive app restarts with AES-256-GCM encryption
- **Offline Support** - Network monitoring with automatic retry when connectivity returns
- **Circuit Breaker** - Protects against failing endpoints with automatic recovery
- **Exponential Backoff** - Smart retry logic with jitter for failed requests
- **Background Processing** - Automatic flush on app background/terminate

#### Privacy & Security
- **Automatic PII Filtering** - Redacts emails, phone numbers, SSNs, credit cards, etc.
- **Queue Encryption** - All persisted events are encrypted with AES-256-GCM
- **Certificate Pinning** - Optional SSL certificate validation
- **Secure Logging** - All debug logs automatically sanitize sensitive data
- **Basic Authentication** - Simple and secure DSN-based auth

#### Developer Experience
- **Real-time Event Monitoring** - AsyncStream for observing event flow
- **Comprehensive Diagnostics** - Built-in metrics and health monitoring
- **Debug Utilities** - Tools for troubleshooting integration issues
- **Swift 6 Compliance** - Full strict concurrency checking with zero warnings
- **iOS 18 Best Practices** - All deprecated APIs replaced with modern alternatives
- **Perfect Build Quality** - Zero compilation warnings on iOS 18.5 + Swift 6
- **Zero Dependencies** - No external dependencies required

#### Configuration Options
- `autoFlushInterval` - Automatic flush interval (default: 30 seconds)
- `maxQueueSize` - Queue size triggering flush (default: 500 events)
- `batchSize` - Events per request (default: 50)
- `requestTimeout` - Network timeout (default: 60 seconds)
- `compressionEnabled` - Zlib compression support (default: true)
- `eventTTL` - Event expiration (default: 7 days)
- `overflowStrategy` - Queue overflow handling (dropOldest, dropNewest, dropAll)

### API Changes from Development Versions

#### Breaking Changes (if upgrading from pre-release versions)
- `LuxAnalytics.shared` is now async - use `await LuxAnalytics.shared`
- `initialize()` is now async - use `await LuxAnalytics.initialize()`
- `setUser()` and `setSession()` are now async - use `await`
- Removed all synchronous API alternatives
- Removed HMAC authentication in favor of DSN-based auth
- `flush()` replaces `flushAsync()` - all operations are async

#### New APIs
- `quickStart(dsn:debugLogging:)` - Simple one-line initialization
- `getCircuitBreakerStatus()` - Monitor endpoint health
- `healthCheck()` - Overall SDK health status
- `LuxAnalyticsEvents.eventStream` - Real-time event monitoring
- `LuxAnalyticsVersion.current` - SDK version information

### Requirements
- iOS 18.0+
- Swift 6.0+
- Xcode 16.0+

### Known Issues
- No macOS support (iOS only)
- Requires async context for all operations
- No synchronous API alternatives

### Migration Notes
This is the initial public release. For migrating from other analytics SDKs or pre-release versions, see our [Migration Guide](MIGRATION.md).