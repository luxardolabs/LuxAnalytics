# Migration Guide

## Migrating from Traditional Analytics SDKs

LuxAnalytics uses modern Swift 6 and iOS 18 features. Here's how to migrate from older patterns:

### Initialization

**Old Pattern (completion-based):**
```swift
Analytics.configure(apiKey: "key") { error in
    if let error = error {
        print("Failed: \(error)")
    }
}
```

**LuxAnalytics (async/await):**
```swift
let config = LuxAnalyticsConfiguration(
    apiURL: URL(string: "https://api.example.com")!,
    keyID: "key-id",
    hmacSecret: "secret"
)
try LuxAnalytics.initialize(with: config)
```

### Tracking Events

**Old Pattern:**
```swift
Analytics.track("event", properties: ["key": "value"]) { success in
    print("Tracked: \(success)")
}
```

**LuxAnalytics:**
```swift
try await LuxAnalytics.shared.track("event", metadata: ["key": "value"])
```

### Event Notifications

**Old Pattern (delegate):**
```swift
class MyClass: AnalyticsDelegate {
    func analyticsDidSendEvents(_ events: [Event]) {
        // Handle
    }
}
analytics.delegate = self
```

**LuxAnalytics (AsyncStream):**
```swift
Task {
    for await notification in LuxAnalyticsEvents.eventStream {
        switch notification {
        case .eventsSent(let events):
            // Handle
        default:
            break
        }
    }
}
```

### Error Handling

**Old Pattern:**
```swift
Analytics.track("event") { result in
    switch result {
    case .success:
        print("Success")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

**LuxAnalytics:**
```swift
do {
    try await LuxAnalytics.shared.track("event")
} catch LuxAnalyticsError.analyticsDisabled {
    // Analytics is disabled
} catch {
    // Other errors
}
```

### Background Processing

**Old Pattern:**
```swift
var backgroundTask: UIBackgroundTaskIdentifier = .invalid
backgroundTask = UIApplication.shared.beginBackgroundTask {
    Analytics.flush()
    UIApplication.shared.endBackgroundTask(backgroundTask)
}
```

**LuxAnalytics:**
```swift
// In AppDelegate
LuxAnalytics.enableBackgroundProcessing()

// Events are automatically flushed in background
// Or manually:
await LuxAnalytics.flushAsync()
```

### Key Differences

1. **No Singleton Access** - Use `LuxAnalytics.shared` after initialization
2. **No Completion Handlers** - Everything is async/await
3. **No Delegates** - Use AsyncStream for notifications
4. **Type Safety** - Errors are thrown, not passed in callbacks
5. **Automatic Retry** - No need to manually retry failed events
6. **Offline Handling** - Automatic, no manual queue management

### Security Changes

1. **No Info.plist Config** - All configuration is programmatic
2. **Encrypted Queue** - Events are encrypted at rest
3. **No API Keys in Code** - Use Keychain or secure injection

### Minimum Requirements

- iOS 18.0+
- Swift 6.0
- Xcode 16.0+

No backwards compatibility is provided. This is a fresh start with modern patterns.