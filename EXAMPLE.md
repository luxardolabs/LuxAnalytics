# LuxAnalytics iOS 18 Usage Example

This SDK requires iOS 18+ and Swift 6. **Zero compilation warnings** with full Swift 6 strict concurrency compliance.

## Basic Setup

```swift
import LuxAnalytics

// Initialize at app startup
let config = try LuxAnalyticsConfiguration(
    dsn: "https://your-key-id@analytics.example.com/api/v1/events/your-project-id"
)

try await LuxAnalytics.initialize(with: config)

// Or use quick start
try await LuxAnalytics.quickStart(
    dsn: "https://your-key-id@analytics.example.com/api/v1/events/your-project-id",
    debugLogging: true
)
```

## Tracking Events

```swift
// Get shared instance (async)
let analytics = await LuxAnalytics.shared

// Simple event tracking with async/await
try await analytics.track("user_login")

// With metadata
try await analytics.track("purchase_completed", metadata: [
    "product_id": "12345",
    "amount": "99.99",
    "currency": "USD"
])

// PII is automatically filtered in all events
try await analytics.track("contact_form", metadata: [
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
// Get shared instance
let analytics = await LuxAnalytics.shared

// Set user ID (async)
await analytics.setUser("user-12345")

// Set session ID (async)
await analytics.setSession("session-abc")
```

## Manual Flush

```swift
// Events are automatically batched and sent
// Force flush when needed (e.g., app backgrounding)
await LuxAnalytics.flush()
```

## Background Processing

```swift
// Background processing is automatically enabled
// Just initialize the SDK and it handles app lifecycle events
@main
struct MyApp: App {
    init() {
        Task {
            try? await LuxAnalytics.quickStart(dsn: "your-dsn")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Configuration Options

```swift
let config = try LuxAnalyticsConfiguration(
    dsn: "https://your-key-id@analytics.example.com/api/v1/events/your-project-id",
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
    let analytics = await LuxAnalytics.shared
    try await analytics.track("event_name")
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
let stats = await LuxAnalytics.getQueueStats()
print("Total events in queue: \(stats.totalEvents)")
print("Total size bytes: \(stats.totalSizeBytes)")
print("Failed batch count: \(stats.failedBatchCount)")

// Check health
let isHealthy = await LuxAnalytics.healthCheck()

// Clear queue (use with caution)
await LuxAnalytics.clearQueue()
```

## Diagnostics

```swift
// Get diagnostic metrics
let metrics = await LuxAnalytics.getDiagnostics()
print("Events sent: \(metrics.networkStats.totalEventsSent)")
print("Events failed: \(metrics.networkStats.totalEventsFailed)")
print("Average flush duration: \(metrics.performanceStats.averageFlushDuration)s")
print("Circuit breaker state: \(metrics.circuitBreakerStatus?.state ?? "unknown")")
```

## Best Practices

1. **Initialize early**: Set up LuxAnalytics in your app delegate or early in app lifecycle
2. **Use structured metadata**: Keep metadata keys consistent across events
3. **Handle errors**: Always handle potential errors when tracking events
4. **Monitor queue size**: Use queue stats to ensure events aren't piling up
5. **Background processing is automatic**: The SDK handles app lifecycle events automatically
6. **PII filtering is automatic**: All events are automatically sanitized