# Changelog

All notable changes to LuxAnalytics will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2025.6.26.0] - 2025-06-26

### Added
- Lazy initialization support with `setPendingConfiguration()` and `lazyShared`
- Safe optional access with `sharedIfInitialized`
- Quick start method `quickStart()` for simple configurations
- Debug utilities in `LuxAnalyticsDebug` for troubleshooting initialization
- Better error messages with detailed debugging information
- Compatibility helpers for common migration mistakes
- Comprehensive security documentation (SECURITY.md)
- Thread-safe singleton implementation using NSLock

### Fixed
- Race condition in singleton initialization
- Certificate pinning now properly integrated in networking layer
- All unit tests now passing with proper setup/teardown
- Thread-safety issues with static properties

### Improved
- Fatal error messages now include helpful debugging information and common fixes
- Added call stack traces to initialization errors
- Documentation updates for initialization best practices
- Security model documentation with threat analysis

### Security
- Certificate pinning is now active when configured
- Proper thread synchronization prevents race conditions
- Enhanced documentation of security best practices

## [1.0.0-beta.1] - 2025-06-25

### Added
- Initial beta release for iOS 18+ and Swift 6
- Core analytics tracking with `async/await` API
- Event queue with AES-GCM encryption
- Automatic retry logic with exponential backoff
- Circuit breaker pattern for failing endpoints
- Network monitoring with automatic offline queuing
- PII filtering with regex-based sanitization
- Certificate pinning support (optional)
- Background task scheduling
- Queue overflow strategies (dropOldest, dropNewest, dropAll)
- Event TTL enforcement
- Request compression for large payloads
- AsyncStream for real-time event notifications
- Comprehensive diagnostic metrics
- Secure logging with automatic redaction
- HMAC-SHA256 request signing

### Security
- All sensitive configuration must be provided programmatically (no Info.plist)
- Queue data encrypted at rest using AES-GCM
- Automatic PII detection and filtering
- Certificate pinning available for enhanced security

### Requirements
- iOS 18.0+
- Swift 6.0
- Xcode 16.0+

### Notes
- This is a complete rewrite with no backwards compatibility
- Delegate pattern replaced with modern AsyncStream
- All APIs are async/await (no completion handlers)
- Built with Swift 6 strict concurrency checking