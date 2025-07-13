# Quick Examples

Common usage patterns for LuxAnalytics. For comprehensive documentation, see the [Wiki](wiki/).

## Basic Setup

```swift
import LuxAnalytics

@main
struct MyApp: App {
    init() {
        Task {
            try await LuxAnalytics.quickStart(
                dsn: "https://your-public-id@analytics.example.com/api/v1/events/your-project-id"
            )
        }
    }
    
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

## Event Tracking

```swift
// Basic event tracking
let analytics = await LuxAnalytics.shared
try await analytics.track("user_signup")

// Event with metadata
try await analytics.track("purchase_completed", metadata: [
    "product_id": "abc123",
    "amount": "49.99",
    "currency": "USD"
])

// User identification
await analytics.setUser("user-123")
await analytics.setSession("session-456")
```

## SwiftUI Integration

```swift
struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Button("Track Event") {
                    Task {
                        let analytics = await LuxAnalytics.shared
                        try await analytics.track("button_tapped")
                    }
                }
            }
        }
        .task {
            let analytics = await LuxAnalytics.shared
            try await analytics.track("screen_viewed", metadata: [
                "screen_name": "content_view"
            ])
        }
    }
}
```

## Error Handling

```swift
func trackEvent(_ name: String) async {
    do {
        let analytics = await LuxAnalytics.shared
        try await analytics.track(name)
    } catch LuxAnalyticsError.notInitialized {
        print("SDK not initialized")
    } catch LuxAnalyticsError.queueFull {
        print("Event queue is full")
    } catch {
        print("Tracking failed: \(error)")
    }
}
```

## App-Specific Analytics Layer

```swift
extension LuxAnalytics {
    static func trackScreen(_ name: String) async {
        guard UserDefaults.standard.bool(forKey: "analytics_enabled") else { return }
        
        let analytics = await LuxAnalytics.shared
        try? await analytics.track("screen_view", metadata: [
            "screen_name": name
        ])
    }
    
    static func trackPurchase(amount: Double, currency: String = "USD") async {
        let analytics = await LuxAnalytics.shared
        
        // Privacy-conscious amount ranges
        let range = switch amount {
            case ..<10: "$0-10"
            case 10..<50: "$10-50"
            case 50..<100: "$50-100"
            default: "$100+"
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

## Configuration Examples

### Info.plist Configuration

```xml
<key>LuxAnalyticsDSN</key>
<string>https://your-public-id@analytics.example.com/api/v1/events/your-project-id</string>

<key>LuxAnalyticsDebugLogging</key>
<true/>

<key>LuxAnalyticsAutoFlushInterval</key>
<real>30.0</real>
```

### Programmatic Configuration

```swift
let config = try LuxAnalyticsConfiguration(
    dsn: "your-dsn",
    autoFlushInterval: 30.0,
    maxQueueSize: 500,
    batchSize: 50,
    debugLogging: true
)

try await LuxAnalytics.initialize(with: config)
```

## Real-time Monitoring

```swift
Task {
    for await notification in LuxAnalyticsEvents.eventStream {
        switch notification {
        case .eventQueued(let event):
            print("📤 Event queued: \(event.name)")
        case .eventsSent(let events):
            print("✅ Sent \(events.count) events")
        case .eventsFailed(let events, let error):
            print("❌ Failed: \(error)")
        }
    }
}
```

## Queue Management

```swift
// Get queue statistics
let stats = await LuxAnalytics.getQueueStats()
print("Events in queue: \(stats.totalEvents)")

// Manual flush
await LuxAnalytics.flush()

// Health check
let isHealthy = await LuxAnalytics.healthCheck()
print("SDK healthy: \(isHealthy)")
```

---

## 📚 More Examples

For comprehensive guides and advanced patterns, see:

- [📖 **Complete Wiki**](wiki/) - Detailed documentation and tutorials
- [🔧 **Configuration Guide**](wiki/Configuration.md) - All configuration options
- [🚀 **API Reference**](wiki/API-Reference.md) - Complete API documentation
- [💡 **Best Practices**](wiki/Best-Practices.md) - Recommended patterns
- [🐛 **Troubleshooting**](wiki/Troubleshooting.md) - Common issues and solutions