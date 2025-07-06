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
        let config = try LuxAnalyticsConfiguration(
            dsn: "https://test-public-id@test.com/api/v1/events/test-project-id"
        )
        try LuxAnalytics.initialize(with: config)
    }
}