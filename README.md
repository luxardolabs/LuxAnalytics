# LuxAnalytics

A **privacy-first**, **high-performance** analytics SDK for iOS built with Swift concurrency best practices. LuxAnalytics provides the core infrastructure for event tracking while letting you build app-specific convenience layers on top.

## ✨ Key Features

- 🔒 **Privacy-First Core** - Secure foundation, you control what data gets tracked
- ⚡ **Zero Main Thread Blocking** - All network operations are fully asynchronous  
- 🎯 **iOS 18 & Swift 6 Ready** - Uses modern Swift concurrency patterns
- 📦 **Automatic Event Batching** - Efficient network usage with intelligent batching
- 🔐 **HMAC Authentication** - Secure event transmission with cryptographic signatures
- 🚀 **Auto-Flush Management** - Handles app lifecycle events automatically
- 💾 **Persistent Queue** - Events persist across app launches
- 🎨 **Highly Configurable** - Customize behavior via Info.plist
- 🛡️ **Production Ready** - Thoroughly tested for enterprise use

## 🚀 Quick Start

### Installation

Add LuxAnalytics to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/luxardolabs/LuxAnalytics", from: "1.0.0")
]
```

### Configuration

Add these keys to your app's `Info.plist`:

```xml
<key>LUX_API_URL</key>
<string>https://your-analytics-endpoint.com/api/events</string>
<key>LUX_HMAC_SECRET</key>
<string>your-hmac-secret-key</string>
<key>LUX_KEY_ID</key>
<string>your-api-key-id</string>

<!-- Optional Configuration -->
<key>LUX_AUTO_FLUSH_INTERVAL</key>
<real>30.0</real>
<key>LUX_MAX_QUEUE_SIZE</key>
<integer>100</integer>
<key>LUX_BATCH_SIZE</key>
<integer>10</integer>
<key>LUX_DEBUG_LOGGING</key>
<true/>
<key>LUX_REQUEST_TIMEOUT</key>
<real>10.0</real>
```

### Basic Usage

```swift
import LuxAnalytics

// Initialize (typically in your App struct)
LuxAnalytics.shared.setUser("user-123")
LuxAnalytics.shared.setSession(UUID().uuidString)

// Track events
LuxAnalytics.shared.track("user_signup", metadata: [
    "method": "email",
    "campaign": "holiday_promotion"
])

// Manual flush (optional - auto-flush handles most cases)
LuxAnalytics.flush()
```

## 📊 Core API

The LuxAnalytics package provides these core methods:

### Event Tracking
```swift
// Basic event tracking
LuxAnalytics.shared.track("event_name", metadata: ["key": "value"])

// User & session management
LuxAnalytics.shared.setUser("user-id")
LuxAnalytics.shared.setSession("session-id")
```

### Settings Management
```swift
// Enable/disable analytics
AnalyticsSettings.shared.isEnabled = true

// Check current state
if AnalyticsSettings.shared.isEnabled {
    // Track event
}
```

### Manual Flushing
```swift
// Simple flush (recommended)
LuxAnalytics.flush()

// Async flush (iOS 15+)
await LuxAnalytics.flushAsync()

// Background flush with completion
LuxAnalytics.flushBackground {
    print("Flush completed")
}
```

### Queue Management
```swift
// Check queue size
let queueSize = LuxAnalyticsQueue.shared.queueSize

// Events are automatically queued and batched
// Manual queue management is typically not needed
```

## 🏗️ Architecture

### Event Flow
```
[Track Event] → [Queue] → [Auto Batch] → [HMAC Sign] → [Send] → [Retry on Fail]
     ↓              ↓           ↓             ↓          ↓           ↓
[Metadata]    [Persist]   [Background]   [Security]  [Async]  [Persistent]
```

### Automatic Behaviors
- **Auto-Flush**: Every 30 seconds (configurable)
- **App Lifecycle**: Flushes on background/terminate
- **Queue Management**: Auto-flush when queue reaches max size
- **Persistence**: Events survive app crashes/force quits
- **Thread Safety**: All operations are thread-safe

## 🎯 Building App-Specific Extensions

LuxAnalytics is designed to be extended with app-specific convenience methods. Here's an example from a real app (LuxBox) that shows the recommended patterns:

### Example: Privacy-First Gift Card App Extension

```swift
// LuxAnalytics+LuxBox.swift - App-specific extension
import LuxAnalytics

extension LuxAnalytics {
    
    // MARK: - App-Specific Screen Names
    struct Screens {
        static let dashboard = "dashboard"
        static let cardList = "card_list"
        static let settings = "settings"
        static let addCard = "add_card"
        // ... more screens
    }
    
    struct Features {
        static let cardManagement = "card_management"
        static let analytics = "analytics"
        static let settings = "settings"
        // ... more features
    }
    
    // MARK: - Privacy-Safe Value Sanitizers
    static func sanitizeAmount(_ amount: Double) -> String {
        switch amount {
        case 0: return "zero"
        case 0.01..<10: return "under_10"
        case 10..<25: return "10_to_25"
        case 25..<50: return "25_to_50"
        case 50..<100: return "50_to_100"
        case 100..<250: return "100_to_250"
        default: return "over_250"
        }
    }
    
    static func sanitizeMerchantName(_ name: String) -> String {
        let lowercased = name.lowercased()
        
        if lowercased.contains("coffee") || lowercased.contains("starbucks") {
            return "coffee_shop"
        } else if lowercased.contains("restaurant") || lowercased.contains("food") {
            return "restaurant"
        } else if lowercased.contains("retail") || lowercased.contains("store") {
            return "retail_store"
        }
        
        return "other_merchant"
    }
    
    static func sanitizeCount(_ count: Int) -> String {
        switch count {
        case 0: return "none"
        case 1: return "one"
        case 2...5: return "few"
        case 6...10: return "several"
        default: return "many"
        }
    }
    
    // MARK: - Convenient Tracking Methods
    static func trackButtonTap(
        _ buttonName: String,
        screen: String,
        feature: String? = nil,
        additionalMetadata: [String: String] = [:]
    ) {
        var metadata = additionalMetadata
        metadata["button_name"] = buttonName
        metadata["screen"] = screen
        
        if let feature = feature {
            metadata["feature"] = feature
        }
        
        shared.track("button_tapped", metadata: metadata)
    }
    
    static func trackScreen(
        _ screenName: String,
        feature: String? = nil,
        previousScreen: String? = nil,
        additionalMetadata: [String: String] = [:]
    ) {
        var metadata = additionalMetadata
        metadata["screen"] = screenName
        
        if let feature = feature {
            metadata["feature"] = feature
        }
        
        if let previousScreen = previousScreen {
            metadata["previous_screen"] = previousScreen
        }
        
        shared.track("screen_viewed", metadata: metadata)
    }
    
    // MARK: - Domain-Specific Tracking
    static func trackCardAction(
        _ action: String,
        card: GiftCard,
        source: String? = nil,
        additionalMetadata: [String: String] = [:]
    ) {
        var metadata = additionalMetadata
        
        // Privacy-safe card metadata using sanitizers
        metadata["merchant_category"] = sanitizeMerchantName(card.retailer)
        metadata["card_value_range"] = sanitizeAmount(card.amount)
        metadata["balance_range"] = sanitizeAmount(card.balance)
        metadata["usage_level"] = sanitizeUsagePercentage(card.usagePercentage)
        metadata["is_favorite"] = String(card.isFavorite)
        metadata["tag_count"] = sanitizeCount(card.tags.count)
        
        if let source = source {
            metadata["source"] = source
        }
        
        metadata["feature"] = Features.cardManagement
        
        shared.track("card_\(action)", metadata: metadata)
    }
    
    static func trackError(
        type: String,
        message: String,
        screen: String,
        feature: String,
        fatal: Bool = false,
        additionalMetadata: [String: String] = [:]
    ) {
        var metadata = additionalMetadata
        metadata["error_type"] = type
        
        // Sanitize error messages to remove PII
        let sanitizedMessage = message
            .replacingOccurrences(of: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#, 
                                with: "[EMAIL]", options: .regularExpression)
            .replacingOccurrences(of: #"\b\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\b"#, 
                                with: "[CARD_NUMBER]", options: .regularExpression)
        
        metadata["error_message"] = sanitizedMessage
        metadata["screen"] = screen
        metadata["feature"] = feature
        metadata["is_fatal"] = String(fatal)
        
        shared.track("error_occurred", metadata: metadata)
    }
}
```

### Usage Examples from Real App

```swift
// Screen tracking
LuxAnalytics.trackScreen(
    LuxAnalytics.Screens.dashboard,
    feature: LuxAnalytics.Features.analytics,
    additionalMetadata: [
        "load_time_ms": String(loadTime)
    ]
)

// Button interactions
LuxAnalytics.trackButtonTap(
    "export_data",
    screen: LuxAnalytics.Screens.settings,
    feature: LuxAnalytics.Features.settings,
    additionalMetadata: [
        "export_format": "json",
        "item_count_range": LuxAnalytics.sanitizeCount(itemCount)
    ]
)

// Domain-specific tracking with privacy protection
LuxAnalytics.trackCardAction(
    "created",
    card: newCard,
    source: "add_card_form",
    additionalMetadata: [
        "creation_method": "manual_entry",
        "has_image": String(hasImage)
    ]
)

// Performance tracking
LuxAnalytics.trackPerformance(
    operation: "load_dashboard",
    durationMs: loadTime,
    success: true,
    additionalMetadata: [
        "data_source": "core_data"
    ]
)
```

### SwiftUI Integration Example

```swift
#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, *)
extension View {
    func trackOnAppear(screen: String, feature: String? = nil) -> some View {
        self.onAppear {
            LuxAnalytics.trackScreen(screen, feature: feature)
        }
    }
    
    func trackTap(buttonName: String, screen: String) -> some View {
        self.onTapGesture {
            LuxAnalytics.trackButtonTap(buttonName, screen: screen)
        }
    }
}
#endif

// Usage in SwiftUI
struct SettingsView: View {
    var body: some View {
        VStack {
            Button("Export Data") {
                // action
            }
            .trackTap(buttonName: "export_data", screen: "settings")
        }
        .trackOnAppear(screen: "settings", feature: "settings")
    }
}
```

## ⚙️ Configuration Options

All configuration is done via `Info.plist`:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `LUX_API_URL` | String | Required | Your analytics endpoint URL |
| `LUX_HMAC_SECRET` | String | Required | HMAC secret for request signing |
| `LUX_KEY_ID` | String | Required | API key identifier |
| `LUX_AUTO_FLUSH_INTERVAL` | Number | 30.0 | Auto-flush interval in seconds |
| `LUX_MAX_QUEUE_SIZE` | Number | 100 | Max events before forced flush |
| `LUX_BATCH_SIZE` | Number | 10 | Events per batch |
| `LUX_DEBUG_LOGGING` | Boolean | false | Enable debug console logs |
| `LUX_REQUEST_TIMEOUT` | Number | 10.0 | Network timeout in seconds |

## 🔒 Security & Privacy

### HMAC Authentication
All requests are signed with HMAC-SHA256:
```
signature = HMAC-SHA256(payload + timestamp, secret)
```

### Privacy Features
- **No automatic PII collection** - You control all data
- **Local queue encryption** - Events stored securely
- **Configurable data retention** - You control server-side storage
- **User consent integration** - Easily disable via `AnalyticsSettings.shared.isEnabled`

### Privacy Best Practices
1. **Sanitize sensitive data** - Use range buckets instead of exact values
2. **Avoid PII in events** - Don't track emails, names, addresses
3. **Use categorical data** - Track "coffee_shop" not "Starbucks on 5th St"
4. **Implement user controls** - Let users disable analytics

## 🛠️ Advanced Usage

### App Lifecycle Integration

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupAnalytics()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    LuxAnalytics.flush() // Auto-handled, but explicit is fine
                }
        }
    }
    
    private func setupAnalytics() {
        LuxAnalytics.shared.setUser(getUserID())
        LuxAnalytics.shared.setSession(UUID().uuidString)
        
        LuxAnalytics.shared.track("app_launched", metadata: [
            "launch_type": isFirstLaunch() ? "first_launch" : "subsequent_launch"
        ])
    }
}
```

### Error Handling

```swift
// LuxAnalytics handles network failures gracefully
// Events are queued and retried automatically
// No special error handling needed in your app

// But you can track your own errors:
do {
    try performRiskyOperation()
} catch {
    LuxAnalytics.trackError(
        type: "operation_failed",
        message: error.localizedDescription,
        screen: "current_screen",
        feature: "risky_operations"
    )
}
```

### Performance Monitoring

```swift
func loadData() async {
    let startTime = Date()
    
    do {
        let data = try await fetchData()
        let duration = Int(Date().timeIntervalSince(startTime) * 1000)
        
        LuxAnalytics.trackPerformance(
            operation: "fetch_data",
            durationMs: duration,
            success: true,
            itemCount: data.count
        )
    } catch {
        let duration = Int(Date().timeIntervalSince(startTime) * 1000)
        
        LuxAnalytics.trackPerformance(
            operation: "fetch_data",
            durationMs: duration,
            success: false
        )
    }
}
```

## 🧪 Testing

### Disable in Tests
```swift
// In your test setup
override func setUp() {
    super.setUp()
    AnalyticsSettings.shared.isEnabled = false
}
```

### Mock for Unit Tests
```swift
// Create a test-specific configuration
class MockLuxAnalytics {
    static var trackedEvents: [(String, [String: String])] = []
    
    static func track(_ name: String, metadata: [String: String] = [:]) {
        trackedEvents.append((name, metadata))
    }
    
    static func reset() {
        trackedEvents.removeAll()
    }
}
```

## 📈 Best Practices

### Event Naming
```swift
// ✅ Good - Clear, consistent naming
"button_tapped"
"screen_viewed"
"card_created"
"error_occurred"

// ❌ Avoid - Inconsistent or unclear
"btnClick"
"pageView"
"newCard"
"exception"
```

### Metadata Structure
```swift
// ✅ Good - Consistent, useful metadata
LuxAnalytics.shared.track("purchase_completed", metadata: [
    "amount_range": "10_to_25",           // Sanitized amount
    "category": "electronics",            // Category, not specific item
    "payment_method": "credit_card",      // Method type
    "is_first_purchase": "true"           // Boolean as string
])

// ❌ Avoid - PII or overly specific data
LuxAnalytics.shared.track("purchase_completed", metadata: [
    "amount": "23.47",                    // Exact amount
    "item": "iPhone 15 Pro Max 256GB",   // Specific product
    "credit_card": "4532-****-****-1234" // PII
])
```

### Performance Considerations
- Events are queued locally and sent in batches
- Network operations never block the main thread
- Auto-flush handles most scenarios - manual flushing rarely needed
- Queue persists across app launches

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

LuxAnalytics is available under the GNU General Public License v3.0. See LICENSE file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/luxardolabs/LuxAnalytics/issues)
- **Documentation**: See inline code documentation
- **Examples**: Check the `/Examples` directory

---

**LuxAnalytics** - Privacy-first analytics that respects your users and performs beautifully. 🚀
