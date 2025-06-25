# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LuxAnalytics is a production-ready iOS analytics SDK written in Swift that provides:
- Swift 6 compliant actor-based architecture
- Comprehensive event tracking with retry logic
- PII filtering and security features
- Network-aware queue management

**Key Technologies:**
- Swift 5.9+ with Swift Package Manager
- iOS 18+ only
- Swift actors for thread safety
- Modern async/await throughout
- CryptoKit for HMAC-SHA256 authentication
- Network framework for connectivity monitoring
- Compression support for large payloads

## Build and Development Commands

### Building
```bash
# Build the library
swift build

# Build for release
swift build -c release

# Clean build
swift build --clean
```

### Testing
```bash
# Run all tests
swift test

# Run specific test
swift test --filter LuxAnalyticsTests.LuxAnalyticsTests/testExample

# Run tests with verbose output
swift test --verbose
```

### Linting
```bash
# Install SwiftLint if not already installed
brew install swiftlint

# Run SwiftLint
swiftlint

# Auto-fix SwiftLint issues
swiftlint --fix
```

## Architecture Overview

### Core Components

1. **LuxAnalytics.swift**: Main entry point
   - Programmatic configuration (no Info.plist)
   - Delegate support for error callbacks
   - Async/await and completion handler APIs
   - Static methods for global operations

2. **AnalyticsActor.swift**: Thread-safe state management
   - Handles all mutable state
   - Lifecycle management
   - Memory warning handling

3. **LuxAnalyticsQueue.swift**: Persistent event queue
   - Actor-based for thread safety
   - Retry logic with exponential backoff
   - TTL enforcement
   - Overflow strategies
   - Queue statistics

4. **NetworkMonitor.swift**: Network connectivity
   - Uses Network framework
   - Prevents sending when offline
   - Automatic retry when connected

5. **PIIFilter.swift**: Privacy protection
   - Regex-based PII detection
   - Sanitization utilities
   - Common PII field detection

6. **CertificatePinning.swift**: Enhanced security
   - Optional certificate pinning
   - SHA256 hash validation
   - Chain validation options

7. **LuxAnalyticsDiagnostics.swift**: SDK health monitoring
   - Performance metrics
   - Network statistics
   - Diagnostic export

### Security Implementation

- HMAC-SHA256 request signing with timestamp validation
- Certificate pinning support (optional)
- PII filtering utilities
- Secure credential storage (host app manages via Keychain)
- Compression for large payloads

### Configuration

All configuration is programmatic via `LuxAnalyticsConfiguration`:
- No Info.plist configuration
- Centralized defaults in `LuxAnalyticsDefaults`
- Host app provides credentials securely

### Event Flow

1. Event created with unique ID
2. Enriched with device context
3. Added to persistent queue (UserDefaults)
4. Retry metadata tracked
5. Network connectivity checked
6. Sent in compressed batches
7. Exponential backoff on failure
8. TTL enforcement
9. Overflow handling

## Key Design Decisions

1. **Actor-based Architecture**: All shared state is protected by actors for Swift 6 compliance
2. **No Info.plist**: Security-first approach, all config is programmatic
3. **UserDefaults Storage**: Appropriate for small queue sizes (<1MB), encrypted with AES-GCM
4. **AsyncStream Pattern**: Modern event notifications without delegates

## Testing Considerations

Comprehensive test coverage includes:
- Configuration validation
- Queue persistence and recovery
- Retry logic with exponential backoff
- Network failure scenarios
- Actor thread safety
- PII filtering

## Integration Steps

1. Add package dependency
2. Initialize with configuration:
```swift
let config = LuxAnalyticsConfiguration(
    apiURL: URL(string: "https://api.example.com")!,
    hmacSecret: getFromKeychain("secret"),
    keyID: getFromKeychain("keyID")
)
try LuxAnalytics.initialize(with: config)
```
3. Set user/session IDs
4. Track events with optional callbacks
5. Enable background processing if needed

## Production Features

- Automatic retry with exponential backoff
- Queue overflow protection
- Network-aware sending
- Compression for large batches
- Memory warning handling
- Background task support
- Certificate pinning
- PII filtering
- Comprehensive diagnostics