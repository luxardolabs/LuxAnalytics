import Foundation
@testable import LuxAnalytics

/// Test helper to reset LuxAnalytics state between tests
struct LuxAnalyticsTestHelper {
    static func reset() {
        // Access the internal state directly for testing
        LuxAnalytics.lock.lock()
        defer { LuxAnalytics.lock.unlock() }
        LuxAnalytics._instance = nil
        LuxAnalyticsConfiguration.current = nil
    }
    
    static func initializeForTesting() throws {
        reset()
        let config = LuxAnalyticsConfiguration(
            apiURL: URL(string: "https://test.com/events")!,
            hmacSecret: "test-secret",
            keyID: "test-key"
        )
        try LuxAnalytics.initialize(with: config)
    }
}