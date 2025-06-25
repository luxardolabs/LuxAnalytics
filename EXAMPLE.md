# LuxAnalytics iOS 18 Usage Example

This SDK requires iOS 18+ and Swift 6.

## Basic Setup

```swift
import LuxAnalytics

// Initialize at app startup
let config = LuxAnalyticsConfiguration(
    apiURL: URL(string: "https://analytics.example.com/v1/events")!,
    keyID: "your-key-id",
    hmacSecret: "your-hmac-secret"
)

try LuxAnalytics.initialize(with: config)
```

## Tracking Events

```swift
// Simple event tracking with async/await
try await LuxAnalytics.shared.track("user_login")

// With metadata
try await LuxAnalytics.shared.track("purchase_completed", metadata: [
    "product_id": "12345",
    "amount": "99.99",
    "currency": "USD"
])

// With PII filtering
try await LuxAnalytics.shared.trackSanitized("contact_form", metadata: [
    "email": "user@example.com",  // Will be redacted
    "phone": "555-1234",          // Will be redacted
    "message": "Hello world"
])
```

## Monitoring Events

```swift
// Monitor analytics events using AsyncStream
Task {
    for await event in LuxAnalyticsEvents.eventStream {
        switch event {
        case .eventQueued(let event):
            print("Event queued: \(event.name)")
            
        case .eventsSent(let events):
            print("Successfully sent \(events.count) events")
            
        case .eventsFailed(let events, let error):
            print("Failed to send \(events.count) events: \(error)")
            
        case .eventsDropped(let count, let reason):
            print("Dropped \(count) events due to: \(reason)")
            
        case .eventsExpired(let events):
            print("Expired \(events.count) events")
        }
    }
}
```

## User & Session Management

```swift
// Set user ID
await LuxAnalytics.shared.setUser("user-12345")

// Set session ID
await LuxAnalytics.shared.setSession("session-abc")
```

## Manual Flush

```swift
// Events are automatically batched and sent
// Force flush when needed (e.g., app backgrounding)
await LuxAnalytics.flushAsync()
```

## Background Processing

```swift
// Enable background task processing in AppDelegate
@MainActor
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    LuxAnalytics.enableBackgroundProcessing()
    return true
}
```

## Configuration Options

```swift
let config = LuxAnalyticsConfiguration(
    apiURL: URL(string: "https://analytics.example.com/v1/events")!,
    keyID: "your-key-id",
    hmacSecret: "your-hmac-secret",
    batchSize: 100,                    // Events per batch
    autoFlushInterval: 30,             // Seconds
    maxQueueSize: 1000,                // Maximum queued events
    maxQueueSizeHard: 2000,            // Hard limit before dropping
    eventTTL: 86400,                   // Event expiry (24 hours)
    maxRetryAttempts: 3,
    requestTimeout: 30,
    compressionEnabled: true,
    compressionThreshold: 1024,        // Bytes
    overflowStrategy: .dropOldest
)
```

## Error Handling

```swift
do {
    try await LuxAnalytics.shared.track("event_name")
} catch LuxAnalyticsError.analyticsDisabled {
    // Analytics is disabled
} catch LuxAnalyticsError.notInitialized {
    // SDK not initialized
} catch {
    // Other errors
}
```

## Queue Management

```swift
// Get queue statistics
if let stats = await LuxAnalytics.getQueueStats() {
    print("Total events in queue: \(stats.totalEvents)")
    print("Retriable events: \(stats.retriableEvents)")
    print("Expired events: \(stats.expiredEvents)")
}

// Check network status
let isOnline = await LuxAnalytics.isNetworkAvailable()

// Clear queue (use with caution)
await LuxAnalytics.clearQueue()
```

## Diagnostics

```swift
// Get diagnostic metrics
let metrics = await LuxAnalyticsDiagnostics.shared.getMetrics()
print("Events sent: \(metrics.eventsSent)")
print("Events failed: \(metrics.eventsFailed)")
print("Average flush duration: \(metrics.averageFlushDuration)s")
print("Circuit breaker state: \(metrics.circuitBreakerMetrics.currentState)")
```

## Best Practices

1. **Initialize early**: Set up LuxAnalytics in your app delegate or early in app lifecycle
2. **Use structured metadata**: Keep metadata keys consistent across events
3. **Handle errors**: Always handle potential errors when tracking events
4. **Monitor queue size**: Use queue stats to ensure events aren't piling up
5. **Enable background processing**: Ensure events are sent even when app backgrounds
6. **Use PII filtering**: Use `trackSanitized` when dealing with user input