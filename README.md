# LuxAnalytics

A **privacy-first**, **high-performance** analytics SDK for iOS 18+ built with Swift 6 and modern concurrency. LuxAnalytics provides secure, reliable event tracking with automatic batching, offline support, and enterprise-grade features. **Zero compilation warnings** with full iOS 18 and Swift 6 strict concurrency compliance.

## ✨ Key Features

- 🔒 **Privacy-First** - Automatic PII filtering, encrypted queue storage
- ⚡ **100% Async/Await** - Modern Swift concurrency throughout
- 🎯 **Swift 6 Compliant** - Full actor isolation and data race safety with zero warnings
- ✨ **Perfect Build Quality** - Zero compilation warnings on iOS 18.5 + Swift 6
- 📦 **Smart Batching** - Automatic event batching with configurable sizes
- 🔐 **DSN Authentication** - Simple configuration with Basic Auth
- 🚀 **Lifecycle Aware** - Automatic flush on background/terminate
- 💾 **Persistent Queue** - Encrypted event storage with AES-256-GCM
- 📡 **Offline Support** - Network monitoring with automatic retry
- 🔄 **Circuit Breaker** - Protects against failing endpoints
- 📊 **Real-time Monitoring** - AsyncStream for event notifications
- 🛡️ **Production Ready** - Comprehensive error handling and recovery

## 🚀 Quick Start

### Installation

Add LuxAnalytics to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/luxardolabs/LuxAnalytics", from: "1.0.0")
]
```

### Basic Setup

```swift
import LuxAnalytics

@main
struct MyApp: App {
    init() {
        Task {
            // Initialize with DSN
            try await LuxAnalytics.quickStart(
                dsn: "https://your-public-id@analytics.example.com/api/v1/events/your-project-id"
            )
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Track Events

```swift
// Track events with async/await
let analytics = await LuxAnalytics.shared
try await analytics.track("user_signup", metadata: [
    "method": "email",
    "source": "app"
])

// User identification
await analytics.setUser("user-123")
await analytics.setSession("session-456")
```

## 📋 Core API Reference

### Initialization

```swift
// Quick start with minimal config
try await LuxAnalytics.quickStart(
    dsn: "https://your-public-id@analytics.example.com/api/v1/events/your-project-id",
    debugLogging: true
)

// Or initialize from Info.plist
try await LuxAnalytics.initializeFromPlist()

// Or with full configuration
let config = try LuxAnalyticsConfiguration(
    dsn: "your-dsn",
    autoFlushInterval: 30.0,
    maxQueueSize: 500,
    batchSize: 50,
    debugLogging: true
)
try await LuxAnalytics.initialize(with: config)
```

### Event Tracking

All SDK operations are async and require `await`:

```swift
// Get the shared instance
let analytics = await LuxAnalytics.shared

// Track events
try await analytics.track("event_name", metadata: [
    "key": "value",
    "timestamp": ISO8601DateFormatter().string(from: Date())
])

// Set user and session (these are async too!)
await analytics.setUser("user-123")
await analytics.setSession("session-456")

// Clear user on logout
await analytics.setUser(nil)
```

### Queue Management

```swift
// Manual flush
await LuxAnalytics.flush()

// Get queue statistics  
let stats = await LuxAnalytics.getQueueStats()
print("Events in queue: \(stats.totalEvents)")
print("Queue size: \(ByteCountFormatter.string(fromByteCount: Int64(stats.totalSizeBytes), countStyle: .file))")

// Clear queue (use with caution)
await LuxAnalytics.clearQueue()

// Check health
let isHealthy = await LuxAnalytics.healthCheck()
```

## 🔧 Configuration

### Info.plist Configuration

Add these keys to your Info.plist:

```xml
<!-- Required -->
<key>LuxAnalyticsDSN</key>
<string>https://your-public-id@analytics.example.com/api/v1/events/your-project-id</string>

<!-- Optional (showing defaults) -->
<key>LuxAnalyticsDebugLogging</key>
<false/>

<key>LuxAnalyticsAutoFlushInterval</key>
<real>30.0</real>

<key>LuxAnalyticsMaxQueueSize</key>
<integer>500</integer>

<key>LuxAnalyticsBatchSize</key>
<integer>50</integer>

<key>LuxAnalyticsRequestTimeout</key>
<real>60.0</real>

<key>LuxAnalyticsCompressionEnabled</key>
<true/>
```

### Programmatic Configuration

```swift
let config = try LuxAnalyticsConfiguration(
    // Required
    dsn: "https://your-public-id@analytics.example.com/api/v1/events/your-project-id",
    
    // Performance tuning
    autoFlushInterval: 30.0,        // Seconds between auto-flushes
    maxQueueSize: 500,              // Events before forcing flush
    batchSize: 50,                  // Events per network request
    
    // Network settings
    requestTimeout: 60.0,           // Network timeout in seconds
    maxRetryAttempts: 5,            // Retry attempts for failed requests
    
    // Queue management
    maxQueueSizeHard: 10000,        // Hard limit before dropping events
    eventTTL: 604800,               // Event time-to-live: 7 days
    overflowStrategy: .dropOldest,  // What to do when queue is full
    
    // Compression
    compressionEnabled: true,       // Enable zlib compression
    compressionThreshold: 1024,     // Compress if payload > 1KB
    
    // Debugging
    debugLogging: false,            // Enable console logging
    
    // Security (optional)
    certificatePinning: nil         // Certificate pinning config
)

try await LuxAnalytics.initialize(with: config)
```

## 📱 Real-time Event Monitoring

Monitor analytics events as they flow through the system:

```swift
Task {
    for await notification in LuxAnalyticsEvents.eventStream {
        switch notification {
        case .eventQueued(let event):
            print("📤 Event queued: \(event.name)")
            
        case .eventsSent(let events):
            print("✅ Sent \(events.count) events")
            
        case .eventsFailed(let events, let error):
            print("❌ Failed to send \(events.count) events: \(error)")
            
        case .eventsDropped(let count, let reason):
            print("⚠️ Dropped \(count) events: \(reason)")
            
        case .eventsExpired(let events):
            print("⏰ Expired \(events.count) old events")
        }
    }
}
```

## 🏗️ Building App-Specific Layers

Create convenience wrappers for your app's specific needs:

```swift
extension LuxAnalytics {
    /// App-specific screen tracking
    static func trackScreen(_ name: String) async {
        guard UserDefaults.standard.bool(forKey: "analytics_enabled") else { return }
        
        let analytics = await LuxAnalytics.shared
        try? await analytics.track("screen_view", metadata: [
            "screen_name": name,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    /// Privacy-conscious purchase tracking
    static func trackPurchase(amount: Double, currency: String = "USD") async {
        let analytics = await LuxAnalytics.shared
        
        // Sanitize exact amounts for privacy
        let range = switch amount {
            case ..<10: "$0-10"
            case 10..<50: "$10-50"
            case 50..<100: "$50-100"
            case 100..<500: "$100-500"
            default: "$500+"
        }
        
        try? await analytics.track("purchase", metadata: [
            "amount_range": range,
            "currency": currency
        ])
    }
}

// Usage
await LuxAnalytics.trackScreen("home")
await LuxAnalytics.trackPurchase(amount: 49.99)
```

## 🛡️ Security Features

- **Automatic PII Filtering**: Redacts emails, phone numbers, SSNs, etc.
- **Queue Encryption**: AES-256-GCM encryption for persisted events
- **Certificate Pinning**: Optional SSL certificate validation
- **Secure Logging**: All logs are automatically sanitized
- **DSN Authentication**: Simple and secure Basic Auth

## 🔍 Debugging

### Enable Debug Logging

```swift
// Via configuration
try await LuxAnalytics.quickStart(
    dsn: "your-dsn",
    debugLogging: true
)

// Or at runtime
await LuxAnalytics.enableDiagnosticMode()
```

### Debug Utilities

```swift
// Check initialization status
await LuxAnalyticsDebug.validateSetup()

// Print current status
await LuxAnalyticsDebug.status()

// Get metrics
let metrics = await LuxAnalytics.getMetrics()
```

### Common Issues

**"Cannot find 'LuxAnalytics' in scope"**
- Make sure you've imported the module: `import LuxAnalytics`

**"'async' property access in a function that does not support concurrency"**
- All LuxAnalytics APIs are async. Make sure you're calling from an async context:
```swift
Task {
    let analytics = await LuxAnalytics.shared
    try await analytics.track("event")
}
```

**Events not sending**
- Check network connectivity: `await LuxAnalytics.isNetworkAvailable()`
- Verify configuration: `await LuxAnalyticsDebug.validateSetup()`
- Check circuit breaker: `await LuxAnalytics.getCircuitBreakerStatus()`

## 📋 Requirements

- **iOS 18.0+** 
- **Swift 6.0+**
- **Xcode 16.0+**

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

## 📄 License

LuxAnalytics is available under the MIT license. See [LICENSE](LICENSE) for details.

## 🆘 Support

- 📧 Email: support@luxardolabs.com
- 🐛 Issues: [GitHub Issues](https://github.com/luxardolabs/LuxAnalytics/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/luxardolabs/LuxAnalytics/discussions)

## 📚 Additional Resources

- [Changelog](docs/CHANGELOG.md)
- [Usage Examples](docs/EXAMPLE.md)
- [Security Guide](docs/SECURITY.md)
- [API Documentation](https://luxardolabs.github.io/LuxAnalytics/)