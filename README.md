# LuxAnalytics

A **privacy-first**, **high-performance** analytics SDK for iOS 18+ built with Swift 6 and modern concurrency. LuxAnalytics provides the core infrastructure for event tracking while letting you build app-specific convenience layers on top.

## ✨ Key Features

- 🔒 **Privacy-First Core** - Secure foundation, you control what data gets tracked
- ⚡ **Zero Main Thread Blocking** - All network operations are fully asynchronous  
- 🎯 **iOS 18+ & Swift 6 Required** - Built exclusively with modern Swift concurrency
- 📦 **Smart Event Batching** - Intelligent batching with retry logic and exponential backoff
- 🔐 **HMAC Authentication** - Secure event transmission with cryptographic signatures
- 🚀 **Auto-Flush Management** - Handles app lifecycle events automatically
- 💾 **Persistent Queue** - Events persist across app launches with TTL and size limits
- 📡 **Offline Support** - Network-aware with automatic retry when connectivity returns
- 🔄 **Retry Logic** - Exponential backoff with jitter for failed events
- 📊 **Queue Monitoring** - Real-time queue statistics and health monitoring
- 🎨 **Highly Configurable** - Extensive configuration options
- 🛡️ **Production Ready** - Battle-tested with comprehensive error handling

### 🆕 New in v2025.6.26.0

- 🔐 **Thread-Safe Singleton** - Proper synchronization using NSLock
- 🧪 **Working Test Suite** - All tests passing with proper teardown/setup
- 📌 **Active Certificate Pinning** - Now properly integrated in networking layer
- 📄 **Security Documentation** - Comprehensive SECURITY.md with threat model
- 🚨 **Better Error Messages** - Detailed debugging info for initialization issues
- 🔄 **Lazy Initialization** - Prevent crashes with pending configuration
- 🛠️ **Debug Utilities** - New tools for troubleshooting setup issues

## 🚀 Quick Start

### Installation

Add LuxAnalytics to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/luxardolabs/LuxAnalytics", from: "2025.6.26.0")
]
```

### ⚠️ Critical: Initialization Order

**IMPORTANT**: LuxAnalytics MUST be initialized before ANY code attempts to access `LuxAnalytics.shared`. This includes:
- Static property initializers
- SwiftUI @StateObject initializers  
- Any singleton init() methods
- View onAppear modifiers that might fire early

Failure to initialize first will result in a fatal error:
```
Fatal error: LuxAnalytics.initialize() must be called before accessing shared instance
```

### Configuration

#### SwiftUI App Lifecycle (Recommended)

```swift
import SwiftUI
import LuxAnalytics

@main
struct MyApp: App {
    @StateObject private var someManager: SomeManager
    
    init() {
        // CRITICAL: Initialize LuxAnalytics FIRST, before any StateObjects
        Self.initializeAnalytics()
        
        // Now safe to initialize StateObjects that might use analytics
        _someManager = StateObject(wrappedValue: SomeManager())
    }
    
    private static func initializeAnalytics() {
        do {
            let config = LuxAnalyticsConfiguration(
                apiURL: URL(string: "https://your-analytics-endpoint.com/api/events")!,
                hmacSecret: getSecretFromKeychain("analytics_hmac_secret"), // Store in Keychain!
                keyID: getSecretFromKeychain("analytics_key_id"),           // Store in Keychain!
                debugLogging: true
            )
            
            try LuxAnalytics.initialize(with: config)
        } catch {
            print("Failed to initialize analytics: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(someManager)
        }
    }
}
```

#### UIKit App Delegate

```swift
import UIKit
import LuxAnalytics

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize LuxAnalytics before any other setup
        initializeAnalytics()
        
        // Now safe to initialize other services
        return true
    }
    
    private func initializeAnalytics() {
        do {
            let config = LuxAnalyticsConfiguration(
                apiURL: URL(string: "https://your-analytics-endpoint.com/api/events")!,
                hmacSecret: getSecretFromKeychain("analytics_hmac_secret"),
                keyID: getSecretFromKeychain("analytics_key_id")
            )
            
            try LuxAnalytics.initialize(with: config)
        } catch {
            print("Failed to initialize analytics: \(error)")
        }
    }
}
```

### ⚠️ Common Initialization Pitfalls

#### ❌ WRONG: StateObject with direct singleton access
```swift
struct MyApp: App {
    // This will crash! SomeManager.shared might use LuxAnalytics in its init
    @StateObject private var manager = SomeManager.shared
    
    init() {
        initializeAnalytics() // Too late!
    }
}
```

#### ✅ CORRECT: Initialize analytics first
```swift
struct MyApp: App {
    @StateObject private var manager: SomeManager
    
    init() {
        Self.initializeAnalytics() // First! (must be static)
        _manager = StateObject(wrappedValue: SomeManager.shared)
    }
}
```

**Important Security Notes:**
- **NEVER** store HMAC secrets or API keys in Info.plist
- **NEVER** commit secrets to source control
- Use iOS Keychain or secure environment injection for sensitive credentials
- Consider using a backend service to provide temporary tokens
- Rotate secrets regularly

### Basic Usage

```swift
import LuxAnalytics

// After initialization, use the shared instance
// Note: setUser and setSession are NOT async
LuxAnalytics.shared.setUser("user-123")
LuxAnalytics.shared.setSession(UUID().uuidString)

// Track events with async/await
try await LuxAnalytics.shared.track("user_signup", metadata: [
    "method": "email",
    "campaign": "holiday_promotion"
])

// Manual flush (optional - auto-flush handles most cases)
await LuxAnalytics.flushAsync()
```

## 📊 Core API Reference

The LuxAnalytics package provides these core methods:

### Initialization & Configuration

```swift
// Initialize (required before any usage)
try LuxAnalytics.initialize(with: configuration)

// Check if initialized
if LuxAnalytics.isInitialized {
    // Safe to use
}

// Access shared instance (only after initialization)
let analytics = LuxAnalytics.shared
```

### Event Tracking

```swift
// Track events (async, throws)
try await LuxAnalytics.shared.track("event_name", metadata: ["key": "value"])

// Track with custom timestamp
try await LuxAnalytics.shared.track(
    "event_name",
    metadata: ["key": "value"],
    timestamp: Date(timeIntervalSinceNow: -60) // 1 minute ago
)
```

### User & Session Management

```swift
// Set user ID (synchronous, non-throwing)
LuxAnalytics.shared.setUser("user-id")

// Set session ID (synchronous, non-throwing)  
LuxAnalytics.shared.setSession("session-id")

// Clear user (for logout)
LuxAnalytics.shared.setUser(nil)
```

### Queue Management

```swift
// Manual flush (returns when complete)
await LuxAnalytics.flushAsync()

// Get queue statistics
let stats = await LuxAnalytics.shared.getQueueStatistics()
print("Events in queue: \(stats.queuedEventCount)")
print("Queue size: \(stats.queueSizeBytes) bytes")
print("Oldest event: \(stats.oldestEventAge) seconds ago")

// Force clear queue (use with caution)
await LuxAnalytics.shared.clearQueue()
```

### Settings Management

```swift
// Enable/disable analytics globally
AnalyticsSettings.shared.isEnabled = true

// Check current state
if AnalyticsSettings.shared.isEnabled {
    // Analytics is active
}

// Disable analytics and clear queue
AnalyticsSettings.shared.isEnabled = false
await LuxAnalytics.shared.clearQueue()
```

## 🏗️ Building App-Specific Convenience Layers

LuxAnalytics is designed as a foundation. You'll typically want to build app-specific convenience methods that add business logic, privacy controls, and consistent naming:

```swift
// Example: App-specific extension with privacy controls
extension LuxAnalytics {
    // Check user preferences before tracking
    private static var isTrackingEnabled: Bool {
        UserDefaults.standard.bool(forKey: "analytics_enabled")
    }
    
    // Note: These are NOT async - they create Tasks internally
    static func trackScreen(_ name: String, metadata: [String: String] = [:]) {
        guard isTrackingEnabled else { return }
        
        var enrichedMetadata = metadata
        enrichedMetadata["screen"] = name
        enrichedMetadata["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        Task {
            try? await shared.track("screen_view", metadata: enrichedMetadata)
        }
    }
    
    static func trackButtonTap(_ button: String, screen: String, metadata: [String: String] = [:]) {
        guard isTrackingEnabled else { return }
        
        var enrichedMetadata = metadata
        enrichedMetadata["button"] = button
        enrichedMetadata["screen"] = screen
        
        Task {
            try? await shared.track("button_tap", metadata: enrichedMetadata)
        }
    }
    
    // Privacy-safe value tracking
    static func trackPurchase(amount: Double, product: String) {
        guard isTrackingEnabled else { return }
        
        // Sanitize exact amounts for privacy
        let amountRange = sanitizeAmount(amount)
        
        Task {
            try? await shared.track("purchase_completed", metadata: [
                "product": product,
                "amount_range": amountRange,
                "currency": Locale.current.currency?.identifier ?? "USD"
            ])
        }
    }
    
    private static func sanitizeAmount(_ amount: Double) -> String {
        switch amount {
        case ..<10: return "$0-10"
        case 10..<50: return "$10-50"
        case 50..<100: return "$50-100"
        case 100..<500: return "$100-500"
        default: return "$500+"
        }
    }
}

// Usage - note no await needed for convenience methods
LuxAnalytics.trackScreen("home")
LuxAnalytics.trackButtonTap("purchase", screen: "product_detail")
LuxAnalytics.trackPurchase(amount: 49.99, product: "premium_monthly")
```

## 📱 Event Notifications & Monitoring

Monitor analytics activity in real-time using AsyncStream:

```swift
Task {
    for await notification in LuxAnalyticsEvents.eventStream {
        switch notification {
        case .eventQueued(let event):
            print("Event queued: \(event.name)")
            
        case .eventsSent(let events):
            print("Successfully sent \(events.count) events")
            
        case .eventsFailed(let events, let error):
            print("Failed to send \(events.count) events: \(error)")
            // Consider retry logic or user notification
            
        case .eventsDropped(let count, let reason):
            print("Dropped \(count) events due to \(reason)")
            
        case .eventsExpired(let events):
            print("Expired \(events.count) old events")
        }
    }
}

// Example: Create a monitor for your app
class AnalyticsMonitor: ObservableObject {
    @Published var queuedEvents = 0
    @Published var droppedEvents = 0
    @Published var lastError: LuxAnalyticsError?
    
    private var task: Task<Void, Never>?
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        task = Task {
            for await notification in LuxAnalyticsEvents.eventStream {
                await MainActor.run {
                    switch notification {
                    case .eventQueued:
                        queuedEvents += 1
                    case .eventsSent(let events):
                        queuedEvents = max(0, queuedEvents - events.count)
                    case .eventsDropped(let count, _):
                        droppedEvents += count
                    case .eventsFailed(_, let error):
                        lastError = error
                    case .eventsExpired(let events):
                        queuedEvents = max(0, queuedEvents - events.count)
                    }
                }
            }
        }
    }
    
    deinit {
        task?.cancel()
    }
}
```

## 🛡️ Security Best Practices

For comprehensive security documentation, see [SECURITY.md](SECURITY.md).

### Configuration Storage

**❌ NEVER store secrets in:**
- Info.plist files
- UserDefaults
- Bundle resources
- Git repositories
- String literals in code

**✅ ALWAYS store secrets in:**
- iOS Keychain
- Secure environment injection
- Backend token service
- CI/CD secure variables

### Example: Keychain Storage

```swift
import Security

// Store secret in Keychain
func storeSecretInKeychain(_ secret: String, for key: String) -> Bool {
    let data = secret.data(using: .utf8)!
    
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ]
    
    // Delete any existing item
    SecItemDelete(query as CFDictionary)
    
    // Add new item
    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
}

// Retrieve secret from Keychain
func getSecretFromKeychain(_ key: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    guard status == errSecSuccess,
          let data = result as? Data,
          let secret = String(data: data, encoding: .utf8) else {
        return nil
    }
    
    return secret
}

// Example: Environment-based configuration
struct AnalyticsConfig {
    static var apiURL: URL {
        #if DEBUG
        return URL(string: "https://staging-analytics.example.com/api/events")!
        #else
        return URL(string: "https://analytics.example.com/api/events")!
        #endif
    }
    
    static var hmacSecret: String {
        // Retrieve from Keychain or secure injection
        getSecretFromKeychain("analytics_hmac_secret") ?? ""
    }
    
    static var keyID: String {
        getSecretFromKeychain("analytics_key_id") ?? ""
    }
}
```

### Network Security

LuxAnalytics includes built-in security features:
- HMAC signature on all requests
- TLS 1.2+ enforcement (iOS minimum)
- Certificate pinning (active when configured)
- Request replay protection
- AES-256-GCM queue encryption

Configure certificate pinning:
```swift
// Generate SHA256 hash of your certificate:
// openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64

let certificatePinning = CertificatePinningConfig(
    pinnedCertificateHashes: ["base64-sha256-hash-here"],
    allowSelfSigned: false,
    validateChain: true
)

let config = LuxAnalyticsConfiguration(
    // ... other config ...
    certificatePinning: certificatePinning
)
```

## 🔧 Advanced Configuration

### Full Configuration Options

```swift
let config = LuxAnalyticsConfiguration(
    // Required parameters
    apiURL: URL(string: "https://api.example.com")!,
    hmacSecret: "your-secret",
    keyID: "your-key-id",
    
    // Network & Performance
    autoFlushInterval: 60.0,        // Seconds between auto-flushes (default: 60)
    maxQueueSize: 100,              // Events before forcing flush (default: 100)
    batchSize: 50,                  // Events per batch (default: 50)
    requestTimeout: 30.0,           // Network timeout in seconds (default: 30)
    maxRetryAttempts: 3,            // Retry attempts for failed requests (default: 3)
    
    // Queue Management  
    maxQueueSizeHard: 1000,         // Hard limit before dropping events (default: 1000)
    eventTTL: 604800,               // Event time-to-live: 7 days (default: 604800)
    overflowStrategy: .dropOldest,  // What to do when queue is full (default: .dropOldest)
    
    // Compression
    compressionEnabled: true,       // Enable gzip compression (default: true)
    compressionThreshold: 1024,     // Compress if payload > 1KB (default: 1024)
    
    // Debugging
    debugLogging: false,            // Enable console logging (default: false)
    
    // Security
    certificatePinning: nil         // Optional certificate pinning
)
```

### Queue Overflow Strategies

```swift
// Drop oldest events (default)
overflowStrategy: .dropOldest

// Drop newest events
overflowStrategy: .dropNewest  

// Clear entire queue
overflowStrategy: .dropAll
```

### Background Processing

LuxAnalytics automatically handles background processing, but you can customize:

```swift
// Enable background task registration
LuxAnalytics.enableBackgroundProcessing()

// Handle background URL session events
func application(_ application: UIApplication,
                handleEventsForBackgroundURLSession identifier: String,
                completionHandler: @escaping () -> Void) {
    LuxAnalytics.handleBackgroundURLSessionEvents(
        identifier: identifier,
        completionHandler: completionHandler
    )
}
```

## 🔍 Debugging & Troubleshooting

### Enable Debug Logging

```swift
let config = LuxAnalyticsConfiguration(
    // ... other config ...
    debugLogging: true
)

// Or enable at runtime
LuxAnalytics.shared.setDebugLogging(true)
```

### Debug Output

With debug logging enabled, you'll see:
```
[LuxAnalytics] ✅ Initialized with endpoint: https://api.example.com
[LuxAnalytics] 📤 Event queued: app_launch (queue size: 1)
[LuxAnalytics] 🔄 Auto-flush triggered (100 events)
[LuxAnalytics] 📡 Sending batch of 50 events...
[LuxAnalytics] ✅ Batch sent successfully
[LuxAnalytics] ⚠️ Network unreachable, queuing events...
[LuxAnalytics] 🔄 Network restored, resuming sends...
```

### Common Issues & Solutions

#### 1. "LuxAnalytics.initialize() must be called before accessing shared instance"
**Cause:** Something is accessing `LuxAnalytics.shared` before initialization

**Solution:** 
- Move initialization earlier in app lifecycle
- Check for static properties that might initialize before your App init
- Make initialization method static if calling from init()
- Check third-party libraries that might use analytics

**Debug:** Add logging to trace initialization order
```swift
// Enable built-in debugging
LuxAnalyticsDebug.debugInitialization = true

print("1. App init started")
Self.initializeAnalytics()
print("2. Analytics initialized")
_stateObject = StateObject(wrappedValue: ...)
print("3. StateObjects created")

// Validate setup
LuxAnalyticsDebug.validateSetup()
```

**Alternative Solutions:**

1. **Use Lazy Initialization:**
```swift
// Early in app lifecycle
LuxAnalytics.setPendingConfiguration(config)

// Later, when needed
LuxAnalytics.lazyShared.track("event")  // Auto-initializes
```

2. **Use Quick Start:**
```swift
try LuxAnalytics.quickStart(
    apiURL: URL(string: "https://api.example.com")!,
    hmacSecret: getFromKeychain("secret"),
    keyID: getFromKeychain("key")
)
```

#### 2. Events not being sent
**Possible causes:**
- Analytics disabled via `AnalyticsSettings.shared.isEnabled`
- Network connectivity issues
- Invalid API endpoint or credentials
- Queue is full and overflow strategy is dropping events

**Debug steps:**
```swift
// Check if enabled
print("Analytics enabled: \(AnalyticsSettings.shared.isEnabled)")

// Monitor network status
for await notification in LuxAnalyticsEvents.eventStream {
    if case .networkStatusChanged(let reachable) = notification {
        print("Network reachable: \(reachable)")
    }
}

// Check queue statistics
let stats = await LuxAnalytics.shared.getQueueStatistics()
print("Queue stats: \(stats)")

// Force a manual flush to test
await LuxAnalytics.flushAsync()
```

#### 3. Memory warnings or high memory usage
**Solutions:**
- Reduce `maxQueueSize` and `maxQueueSizeHard`
- Use more aggressive `overflowStrategy` (.dropOldest)
- Reduce `eventTTL` to expire old events sooner
- Monitor queue size and flush manually if needed

```swift
// More aggressive configuration for memory-constrained apps
let config = LuxAnalyticsConfiguration(
    // ... required params ...
    maxQueueSize: 50,           // Flush more frequently
    maxQueueSizeHard: 200,      // Lower hard limit
    eventTTL: 86400,            // 1 day instead of 7
    overflowStrategy: .dropOldest
)
```

#### 4. Build errors after upgrading
**"No 'async' operations occur within 'await' expression"**
- Remove `await` from `setUser()` and `setSession()` calls
- Check your app-specific extensions aren't marked as async

**"No calls to throwing functions occur within 'try' expression"**
- Remove `try` from methods that don't throw
- Only `track()` and `initialize()` throw

### Testing Analytics

```swift
// Create a test harness
class AnalyticsTestHarness {
    private var receivedEvents: [LuxAnalyticsNotification] = []
    private var task: Task<Void, Never>?
    
    func startCapturing() {
        task = Task {
            for await notification in LuxAnalyticsEvents.eventStream {
                receivedEvents.append(notification)
            }
        }
    }
    
    func stopCapturing() {
        task?.cancel()
    }
    
    func assertEventSent(named eventName: String) -> Bool {
        return receivedEvents.contains { notification in
            if case .eventQueued(let event) = notification {
                return event.name == eventName
            }
            return false
        }
    }
}

// Use in XCTest
func testAnalyticsTracking() async {
    let harness = AnalyticsTestHarness()
    harness.startCapturing()
    
    try await LuxAnalytics.shared.track("test_event")
    
    // Wait for processing
    try await Task.sleep(nanoseconds: 100_000_000)
    
    XCTAssertTrue(harness.assertEventSent(named: "test_event"))
    harness.stopCapturing()
}
```

## 🔄 Migration from Other Analytics SDKs

See [MIGRATION.md](MIGRATION.md) for detailed migration guides from:
- Google Analytics
- Firebase Analytics
- Mixpanel
- Amplitude
- Custom analytics solutions

## 📋 Requirements

- **iOS 18.0+** (uses latest Swift concurrency features)
- **Swift 6.0** (required for complete concurrency checking)
- **Xcode 16.0+**

No backwards compatibility is provided. This SDK is built exclusively with modern patterns.

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

1. Clone the repository
2. Open `Package.swift` in Xcode 16+
3. Run tests with `Cmd+U`

### Running Tests

```bash
swift test

# With coverage
swift test --enable-code-coverage

# Specific test
swift test --filter LuxAnalyticsTests.EventQueueTests
```

## 📄 License

LuxAnalytics is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## 🆘 Support

- 📧 Email: support@luxardolabs.com
- 🐛 Issues: [GitHub Issues](https://github.com/luxardolabs/LuxAnalytics/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/luxardolabs/LuxAnalytics/discussions)

## 🗺️ Roadmap

### Version 2.0 (Q2 2024)
- [ ] SwiftUI view modifiers for automatic screen tracking
- [ ] Codable event types with compile-time validation
- [ ] Built-in user properties management
- [ ] Session replay capabilities

### Version 2.1 (Q3 2024)
- [ ] A/B testing framework integration
- [ ] Real-time event streaming
- [ ] Advanced user segmentation
- [ ] Export to BigQuery/Snowflake

## 📚 Additional Resources

- [API Documentation](https://luxardolabs.github.io/LuxAnalytics/)
- [Example App](https://github.com/luxardolabs/LuxAnalytics/tree/main/Example)
- [Best Practices Guide](https://github.com/luxardolabs/LuxAnalytics/wiki/Best-Practices)
- [Performance Tuning](https://github.com/luxardolabs/LuxAnalytics/wiki/Performance)