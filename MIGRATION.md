# Migration Guide for LuxAnalytics v2025.6.26.0

## Breaking Changes from Previous Versions

### 1. Initialization is Now Required

**Before:**
```swift
// Could use Analytics.shared immediately
Analytics.shared.track("event")
```

**After:**
```swift
// MUST initialize first
try LuxAnalytics.initialize(with: config)
// Then use shared instance
try await LuxAnalytics.shared.track("event")
```

**⚠️ CRITICAL:** Accessing `LuxAnalytics.shared` before initialization causes a fatal error.

### 2. Configuration No Longer Uses Info.plist

**Before (Info.plist):**
```xml
<key>LUX_KEY_ID</key>
<string>your-key-id</string>
<key>LUX_HMAC_SECRET</key>
<string>your-secret</string>
<key>LUX_API_URL</key>
<string>https://api.example.com</string>
```

**After (Programmatic):**
```swift
let config = LuxAnalyticsConfiguration(
    apiURL: URL(string: "https://api.example.com")!,
    hmacSecret: getFromKeychain("hmac_secret"),
    keyID: getFromKeychain("key_id")
)
try LuxAnalytics.initialize(with: config)
```

### 3. Method Signature Changes

#### User and Session Management

**Before:**
```swift
// These were async in some versions
await Analytics.setUser("user-id")
await Analytics.setSession("session-id")
```

**After:**
```swift
// Now synchronous (they create Tasks internally)
LuxAnalytics.shared.setUser("user-id")      // No await
LuxAnalytics.shared.setSession("session-id") // No await
```

#### Event Tracking

**Before:**
```swift
// Completion handler based
Analytics.track("event", properties: ["key": "value"]) { error in
    if let error = error {
        print("Failed: \(error)")
    }
}
```

**After:**
```swift
// Async/await with throwing
do {
    try await LuxAnalytics.shared.track("event", metadata: ["key": "value"])
} catch {
    print("Failed: \(error)")
}
```

### 4. Error Handling Pattern Changes

**Before:**
```swift
// Errors in callbacks
Analytics.configure(apiKey: "key") { error in
    if let error = error {
        // Handle error
    }
}
```

**After:**
```swift
// Thrown errors
do {
    try LuxAnalytics.initialize(with: config)
} catch LuxAnalyticsError.alreadyInitialized {
    // Already initialized
} catch {
    // Other errors
}
```

## Step-by-Step Migration Guide

### Step 1: Update Package Dependency

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/luxardolabs/LuxAnalytics", from: "2025.6.25.1")
]
```

### Step 2: Fix Initialization Order

#### SwiftUI Apps

**Common Issue:** StateObjects that use analytics in their init

```swift
// ❌ This will crash
@main
struct MyApp: App {
    @StateObject private var manager = Manager() // Manager uses LuxAnalytics
    
    init() {
        setupAnalytics() // Too late!
    }
}

// ✅ This works
@main
struct MyApp: App {
    @StateObject private var manager: Manager
    
    init() {
        // Initialize analytics FIRST
        Self.setupAnalytics()
        
        // Then create StateObjects
        _manager = StateObject(wrappedValue: Manager())
    }
    
    private static func setupAnalytics() {
        // Must be static to call from init
        do {
            let config = LuxAnalyticsConfiguration(...)
            try LuxAnalytics.initialize(with: config)
        } catch {
            print("Analytics init failed: \(error)")
        }
    }
}
```

### Step 3: Update All Analytics Calls

#### Find and Replace Patterns

1. **Remove await from setUser/setSession:**
   ```swift
   // Find: await LuxAnalytics.shared.setUser
   // Replace: LuxAnalytics.shared.setUser
   ```

2. **Update track calls:**
   ```swift
   // Find: Analytics.track("event", properties:
   // Replace: try await LuxAnalytics.shared.track("event", metadata:
   ```

3. **Update property names:**
   ```swift
   // Find: properties:
   // Replace: metadata:
   ```

### Step 4: Update Error Handling

**Before:**
```swift
Analytics.track("event") { success in
    if !success {
        print("Failed to track")
    }
}
```

**After:**
```swift
Task {
    do {
        try await LuxAnalytics.shared.track("event")
    } catch {
        print("Failed to track: \(error)")
    }
}
```

### Step 5: Update Custom Extensions

If you have app-specific analytics helpers:

**Before:**
```swift
extension Analytics {
    static func trackScreen(_ name: String) async {
        await shared.track("screen_view", properties: ["screen": name])
    }
}
```

**After:**
```swift
extension LuxAnalytics {
    // Note: Make these synchronous if they just create Tasks
    static func trackScreen(_ name: String) {
        Task {
            try? await shared.track("screen_view", metadata: ["screen": name])
        }
    }
}
```

### Step 6: Handle Background Processing

**Before:**
```swift
// Manual background task management
var backgroundTask: UIBackgroundTaskIdentifier = .invalid
backgroundTask = UIApplication.shared.beginBackgroundTask {
    Analytics.flush()
    UIApplication.shared.endBackgroundTask(backgroundTask)
}
```

**After:**
```swift
// Automatic - LuxAnalytics handles this
// Or manually if needed:
Task {
    await LuxAnalytics.flushAsync()
}
```

## Common Migration Issues and Solutions

### Issue 1: "Fatal error: LuxAnalytics.initialize() must be called"

**Cause:** Something is accessing LuxAnalytics.shared before initialization

**Solution:** 
1. Check for static properties that initialize early
2. Move initialization to the very beginning of your app lifecycle
3. Make initialization method static if calling from init()

### Issue 2: Build Errors - "No 'async' operations occur within 'await' expression"

**Cause:** Methods like setUser/setSession are no longer async

**Solution:** Remove `await` keyword from these calls

### Issue 3: "Cannot find 'Analytics' in scope"

**Cause:** Class renamed from Analytics to LuxAnalytics

**Solution:** Global find/replace Analytics → LuxAnalytics

### Issue 4: Configuration Not Working

**Cause:** Still trying to use Info.plist configuration

**Solution:** 
1. Remove all LUX_* keys from Info.plist
2. Create programmatic configuration
3. Store secrets in Keychain, not Info.plist

## Testing Your Migration

### 1. Verify Initialization Order

Add logging to verify order:
```swift
init() {
    print("1. App init started")
    Self.initializeAnalytics()
    print("2. Analytics initialized")
    _stateObject = StateObject(wrappedValue: ...)
    print("3. StateObjects created")
}
```

### 2. Test Event Tracking

```swift
// Add debug logging
let config = LuxAnalyticsConfiguration(
    // ... your config ...
    debugLogging: true  // Enable console output
)

// Verify events are queued
Task {
    for await notification in LuxAnalyticsEvents.eventStream {
        print("Analytics: \(notification)")
    }
}
```

### 3. Verify Network Calls

Use Charles Proxy or similar to verify:
- Events are batched correctly
- HMAC signatures are included
- Retry logic works on failures

## Rollback Plan

If you need to rollback:

1. Keep your old analytics code in a feature flag:
   ```swift
   if useNewAnalytics {
       try await LuxAnalytics.shared.track(...)
   } else {
       OldAnalytics.track(...)
   }
   ```

2. Test thoroughly in staging before production deployment

3. Monitor crash reports for initialization errors

## New Helper Methods (v2025.6.26.0+)

To make migration easier, we've added several helper methods:

### Lazy Initialization

If you can't initialize early enough, use lazy initialization:

```swift
// Set config early (e.g., in a static initializer)
LuxAnalytics.setPendingConfiguration(config)

// Later, use lazyShared which auto-initializes
LuxAnalytics.lazyShared.track("event")  // Auto-initializes on first use

// Or check if initialized first
if let analytics = LuxAnalytics.sharedIfInitialized {
    analytics.track("event")
}
```

### Quick Start

For simple configurations:

```swift
try LuxAnalytics.quickStart(
    apiURL: URL(string: "https://api.example.com")!,
    hmacSecret: getFromKeychain("secret"),
    keyID: getFromKeychain("key"),
    debugLogging: true
)
```

### Debug Tools

Enable initialization debugging to trace issues:

```swift
// Enable debug mode
LuxAnalyticsDebug.debugInitialization = true

// Validate your setup
LuxAnalyticsDebug.validateSetup()
```

This will show:
- When initialization is attempted
- When shared instance is accessed
- Current initialization status
- Common setup issues to check

### Better Error Messages

If initialization order is wrong, you'll now see helpful error messages with:
- Common causes of the error
- Specific fixes to try
- Call stack to trace the issue
- Direct link to documentation

## What's New in v2025.6.26.0

### Thread-Safe Singleton Implementation

The singleton is now properly thread-safe using NSLock synchronization instead of `nonisolated(unsafe)`. This prevents potential race conditions during initialization.

### Certificate Pinning is Now Active

Certificate pinning was implemented but not being used. It's now properly integrated:

```swift
let certificatePinning = CertificatePinningConfig(
    pinnedCertificateHashes: ["your-cert-sha256-hash"],
    allowSelfSigned: false,
    validateChain: true
)

let config = LuxAnalyticsConfiguration(
    // ... other config ...
    certificatePinning: certificatePinning
)
```

### Enhanced Security

- Queue encryption with AES-256-GCM
- Automatic PII filtering
- Secure logging with redaction
- Comprehensive security documentation in SECURITY.md

### Improved Testing

All unit tests are now passing with proper setup/teardown. If you're testing LuxAnalytics:

```swift
// In your test setup
override func setUp() async throws {
    try await super.setUp()
    // Reset state between tests
    LuxAnalyticsTestHelper.reset()
}
```

## Need Help?

Common resources:
- Check debug logs with `debugLogging: true`
- Enable `LuxAnalyticsDebug.debugInitialization = true` for init issues
- Run `LuxAnalyticsDebug.validateSetup()` to check configuration
- Monitor `LuxAnalyticsEvents.eventStream` for queue activity
- File issues at: https://github.com/luxardolabs/LuxAnalytics/issues