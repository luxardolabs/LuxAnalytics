# Migration Guide

## Migrating to LuxAnalytics 1.0.0

### From Pre-Release Versions

If you were using a pre-release version of LuxAnalytics, here are the breaking changes:

#### 1. All APIs are now async

**Before:**
```swift
// Synchronous access
let analytics = LuxAnalytics.shared
analytics.setUser("user-123")
analytics.setSession("session-456")

// Fire-and-forget tracking
LuxAnalytics.shared.track("event_name")
```

**After:**
```swift
// Async access required
let analytics = await LuxAnalytics.shared
await analytics.setUser("user-123")
await analytics.setSession("session-456")

// Async tracking with error handling
try await analytics.track("event_name")
```

#### 2. Initialization is async

**Before:**
```swift
try LuxAnalytics.initialize(with: config)
```

**After:**
```swift
try await LuxAnalytics.initialize(with: config)
```

#### 3. Authentication changed from HMAC to DSN

**Before:**
```swift
let config = LuxAnalyticsConfiguration(
    endpoint: URL(string: "https://api.example.com")!,
    publicId: "public-123",
    hmacSecret: "secret-key",
    keyId: "key-123"
)
```

**After:**
```swift
let config = try LuxAnalyticsConfiguration(
    dsn: "https://public-123@api.example.com/api/v1/events/project-id"
)
```

### From Other Analytics SDKs

#### From Google Analytics

**Google Analytics:**
```swift
Analytics.logEvent("user_signup", parameters: [
    "method": "email",
    "source": "app"
])
```

**LuxAnalytics:**
```swift
let analytics = await LuxAnalytics.shared
try await analytics.track("user_signup", metadata: [
    "method": "email",
    "source": "app"
])
```

#### From Mixpanel

**Mixpanel:**
```swift
Mixpanel.mainInstance().track(event: "Product Viewed", properties: [
    "product_id": "12345",
    "price": 29.99
])
Mixpanel.mainInstance().identify(distinctId: "user-123")
```

**LuxAnalytics:**
```swift
let analytics = await LuxAnalytics.shared
await analytics.setUser("user-123")
try await analytics.track("product_viewed", metadata: [
    "product_id": "12345",
    "price": "29.99"
])
```

#### From Amplitude

**Amplitude:**
```swift
Amplitude.instance().logEvent("checkout_started")
Amplitude.instance().setUserId("user-123")
```

**LuxAnalytics:**
```swift
let analytics = await LuxAnalytics.shared
await analytics.setUser("user-123")
try await analytics.track("checkout_started")
```

### Common Migration Patterns

#### 1. Wrapping in Tasks

Since all LuxAnalytics APIs are async, you'll need to wrap calls in Task blocks when calling from synchronous contexts:

```swift
// SwiftUI View
struct ContentView: View {
    var body: some View {
        Button("Track Event") {
            Task {
                let analytics = await LuxAnalytics.shared
                try? await analytics.track("button_tapped")
            }
        }
    }
}

// UIKit
@IBAction func buttonTapped() {
    Task {
        let analytics = await LuxAnalytics.shared
        try? await analytics.track("button_tapped")
    }
}
```

#### 2. Creating Convenience Wrappers

To avoid boilerplate, create app-specific wrappers:

```swift
extension LuxAnalytics {
    static func trackEvent(_ name: String, metadata: [String: String] = [:]) {
        Task {
            let analytics = await LuxAnalytics.shared
            try? await analytics.track(name, metadata: metadata)
        }
    }
}

// Usage - no Task needed
LuxAnalytics.trackEvent("screen_viewed", metadata: ["screen": "home"])
```

#### 3. Error Handling

LuxAnalytics only throws errors for initialization and tracking:

```swift
do {
    // Initialization can throw
    try await LuxAnalytics.quickStart(dsn: "your-dsn")
    
    // Tracking can throw
    let analytics = await LuxAnalytics.shared
    try await analytics.track("event")
} catch LuxAnalyticsError.notInitialized {
    print("Analytics not initialized")
} catch LuxAnalyticsError.analyticsDisabled {
    print("Analytics is disabled")
} catch {
    print("Other error: \(error)")
}
```

### Frequently Asked Questions

**Q: Why is everything async?**
A: LuxAnalytics uses actors for thread safety, which requires async access. This ensures your app is safe from data races and follows Swift 6 best practices.

**Q: Can I get synchronous APIs?**
A: No. The SDK is designed exclusively for modern Swift concurrency. You can create wrapper functions that use Task {} if needed.

**Q: How do I handle the async shared instance?**
A: Store it in a property if you need repeated access:
```swift
class ViewModel {
    private var analytics: LuxAnalytics?
    
    func setup() async {
        analytics = await LuxAnalytics.shared
    }
    
    func trackEvent() async {
        try? await analytics?.track("event")
    }
}
```

**Q: What about SwiftUI @StateObject?**
A: Initialize analytics before creating StateObjects:
```swift
@main
struct MyApp: App {
    init() {
        Task {
            try? await LuxAnalytics.quickStart(dsn: "your-dsn")
        }
    }
}
```

### Need Help?

- 📧 Email: support@luxardolabs.com
- 💬 GitHub Discussions: [github.com/luxardolabs/LuxAnalytics/discussions](https://github.com/luxardolabs/LuxAnalytics/discussions)
- 🐛 Issues: [github.com/luxardolabs/LuxAnalytics/issues](https://github.com/luxardolabs/LuxAnalytics/issues)