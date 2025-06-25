import XCTest
@testable import LuxAnalytics

final class LuxAnalyticsTests: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        // Clear any existing state
        await LuxAnalytics.clearQueue()
        await AnalyticsSettings.shared.setEnabled(true)
    }
    
    override func tearDown() async throws {
        await LuxAnalytics.clearQueue()
        try await super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testInitialization() throws {
        let config = LuxAnalyticsConfiguration(
            apiURL: URL(string: "https://test.com/events")!,
            hmacSecret: "test-secret",
            keyID: "test-key"
        )
        
        XCTAssertNoThrow(try LuxAnalytics.initialize(with: config))
        XCTAssertTrue(LuxAnalytics.isInitialized)
    }
    
    func testDoubleInitializationThrows() throws {
        let config = LuxAnalyticsConfiguration(
            apiURL: URL(string: "https://test.com/events")!,
            hmacSecret: "test-secret",
            keyID: "test-key"
        )
        
        try LuxAnalytics.initialize(with: config)
        
        XCTAssertThrowsError(try LuxAnalytics.initialize(with: config)) { error in
            XCTAssertEqual(error as? LuxAnalyticsError, .alreadyInitialized)
        }
    }
    
    func testDefaultConfiguration() {
        let config = LuxAnalyticsConfiguration(
            apiURL: URL(string: "https://test.com/events")!,
            hmacSecret: "test-secret",
            keyID: "test-key"
        )
        
        XCTAssertEqual(config.autoFlushInterval, LuxAnalyticsDefaults.autoFlushInterval)
        XCTAssertEqual(config.maxQueueSize, LuxAnalyticsDefaults.maxQueueSize)
        XCTAssertEqual(config.batchSize, LuxAnalyticsDefaults.batchSize)
        XCTAssertEqual(config.debugLogging, LuxAnalyticsDefaults.debugLogging)
        XCTAssertEqual(config.requestTimeout, LuxAnalyticsDefaults.requestTimeout)
        XCTAssertEqual(config.maxQueueSizeHard, LuxAnalyticsDefaults.maxQueueSizeHard)
        XCTAssertEqual(config.eventTTL, LuxAnalyticsDefaults.eventTTL)
        XCTAssertEqual(config.maxRetryAttempts, LuxAnalyticsDefaults.maxRetryAttempts)
        XCTAssertEqual(config.overflowStrategy, LuxAnalyticsDefaults.overflowStrategy)
    }
    
    func testCustomConfiguration() {
        let config = LuxAnalyticsConfiguration(
            apiURL: URL(string: "https://test.com/events")!,
            hmacSecret: "test-secret",
            keyID: "test-key",
            autoFlushInterval: 60,
            maxQueueSize: 200,
            batchSize: 20,
            debugLogging: true,
            requestTimeout: 30,
            maxQueueSizeHard: 1000,
            eventTTL: 86400,
            maxRetryAttempts: 3,
            overflowStrategy: .dropNewest
        )
        
        XCTAssertEqual(config.autoFlushInterval, 60)
        XCTAssertEqual(config.maxQueueSize, 200)
        XCTAssertEqual(config.batchSize, 20)
        XCTAssertEqual(config.debugLogging, true)
        XCTAssertEqual(config.requestTimeout, 30)
        XCTAssertEqual(config.maxQueueSizeHard, 1000)
        XCTAssertEqual(config.eventTTL, 86400)
        XCTAssertEqual(config.maxRetryAttempts, 3)
        XCTAssertEqual(config.overflowStrategy, .dropNewest)
    }
}

// MARK: - Analytics Settings Tests
final class AnalyticsSettingsTests: XCTestCase {
    
    func testSettingsEnabled() async {
        await AnalyticsSettings.shared.setEnabled(true)
        let isEnabled = await AnalyticsSettings.shared.isEnabled
        XCTAssertTrue(isEnabled)
    }
    
    func testSettingsDisabled() async {
        await AnalyticsSettings.shared.setEnabled(false)
        let isEnabled = await AnalyticsSettings.shared.isEnabled
        XCTAssertFalse(isEnabled)
    }
    
    func testSettingsPersistence() async {
        // Set to false
        await AnalyticsSettings.shared.setEnabled(false)
        
        // Create new instance (simulating app restart)
        let newSettings = AnalyticsSettings()
        let isEnabled = await newSettings.isEnabled
        XCTAssertFalse(isEnabled)
        
        // Clean up
        await AnalyticsSettings.shared.setEnabled(true)
    }
}

// MARK: - Queue Tests
final class LuxAnalyticsQueueTests: XCTestCase {
    
    func testQueueEnqueue() async {
        let event = AnalyticsEvent(
            name: "test_event",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            userId: "user123",
            sessionId: "session123",
            metadata: ["key": "value"]
        )
        
        let initialSize = await LuxAnalyticsQueue.shared.queueSize
        await LuxAnalyticsQueue.shared.enqueue(event)
        let newSize = await LuxAnalyticsQueue.shared.queueSize
        
        XCTAssertEqual(newSize, initialSize + 1)
    }
    
    func testQueueClear() async {
        let event = AnalyticsEvent(
            name: "test_event",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            userId: nil,
            sessionId: nil,
            metadata: [:]
        )
        
        await LuxAnalyticsQueue.shared.enqueue(event)
        await LuxAnalyticsQueue.shared.enqueue(event)
        
        await LuxAnalyticsQueue.shared.clear()
        let size = await LuxAnalyticsQueue.shared.queueSize
        
        XCTAssertEqual(size, 0)
    }
    
    func testQueueStats() async {
        await LuxAnalyticsQueue.shared.clear()
        
        // Add some events
        for i in 0..<5 {
            let event = AnalyticsEvent(
                name: "test_event_\(i)",
                timestamp: ISO8601DateFormatter().string(from: Date()),
                userId: nil,
                sessionId: nil,
                metadata: [:]
            )
            await LuxAnalyticsQueue.shared.enqueue(event)
        }
        
        let stats = await LuxAnalyticsQueue.shared.getQueueStats()
        XCTAssertEqual(stats.totalEvents, 5)
        XCTAssertEqual(stats.retriableEvents, 5)
        XCTAssertEqual(stats.expiredEvents, 0)
        XCTAssertLessThan(stats.oldestEventAge, 1) // Should be very recent
    }
}

// MARK: - Event Tests
final class AnalyticsEventTests: XCTestCase {
    
    func testEventCreation() {
        let event = AnalyticsEvent(
            name: "test_event",
            timestamp: "2024-01-01T00:00:00Z",
            userId: "user123",
            sessionId: "session123",
            metadata: ["key": "value"]
        )
        
        XCTAssertEqual(event.name, "test_event")
        XCTAssertEqual(event.timestamp, "2024-01-01T00:00:00Z")
        XCTAssertEqual(event.userId, "user123")
        XCTAssertEqual(event.sessionId, "session123")
        XCTAssertEqual(event.metadata["key"], "value")
        XCTAssertFalse(event.id.isEmpty)
    }
    
    func testEventCodable() throws {
        let event = AnalyticsEvent(
            name: "test_event",
            timestamp: "2024-01-01T00:00:00Z",
            userId: "user123",
            sessionId: "session123",
            metadata: ["key": "value"]
        )
        
        let encoded = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(AnalyticsEvent.self, from: encoded)
        
        XCTAssertEqual(event.id, decoded.id)
        XCTAssertEqual(event.name, decoded.name)
        XCTAssertEqual(event.timestamp, decoded.timestamp)
        XCTAssertEqual(event.userId, decoded.userId)
        XCTAssertEqual(event.sessionId, decoded.sessionId)
        XCTAssertEqual(event.metadata["key"], decoded.metadata["key"])
    }
}

// MARK: - Queued Event Tests
final class QueuedEventTests: XCTestCase {
    
    func testQueuedEventExpiry() {
        let event = AnalyticsEvent(
            name: "test",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            userId: nil,
            sessionId: nil,
            metadata: [:]
        )
        
        var queuedEvent = QueuedEvent(event: event)
        
        // Not expired
        XCTAssertFalse(queuedEvent.isExpired(ttlSeconds: 3600))
        
        // Simulate old event
        queuedEvent = QueuedEvent(event: event)
        // We can't easily test actual expiry without modifying the struct
        // In production, we'd use dependency injection for Date
    }
    
    func testRetryDelay() {
        let event = AnalyticsEvent(
            name: "test",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            userId: nil,
            sessionId: nil,
            metadata: [:]
        )
        
        var queuedEvent = QueuedEvent(event: event)
        
        // First retry - ~2 seconds
        queuedEvent.retryCount = 0
        let delay1 = queuedEvent.nextRetryDelay()
        XCTAssertGreaterThan(delay1, 1.5)
        XCTAssertLessThan(delay1, 2.5)
        
        // Second retry - ~4 seconds
        queuedEvent.retryCount = 1
        let delay2 = queuedEvent.nextRetryDelay()
        XCTAssertGreaterThan(delay2, 3)
        XCTAssertLessThan(delay2, 5)
        
        // Max delay
        queuedEvent.retryCount = 100
        let delayMax = queuedEvent.nextRetryDelay()
        XCTAssertLessThanOrEqual(delayMax, 375) // 300 + 25% jitter
    }
    
    func testShouldRetry() {
        let event = AnalyticsEvent(
            name: "test",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            userId: nil,
            sessionId: nil,
            metadata: [:]
        )
        
        var queuedEvent = QueuedEvent(event: event)
        
        // Should retry initially
        XCTAssertTrue(queuedEvent.shouldRetry(maxRetries: 3))
        
        // Should not retry after max attempts
        queuedEvent.retryCount = 3
        XCTAssertFalse(queuedEvent.shouldRetry(maxRetries: 3))
    }
}

// MARK: - Network Monitor Tests
final class NetworkMonitorTests: XCTestCase {
    
    func testNetworkMonitorSingleton() async {
        let monitor1 = NetworkMonitor.shared
        let monitor2 = NetworkMonitor.shared
        XCTAssertTrue(monitor1 === monitor2)
    }
    
    func testNetworkMonitorProperties() async {
        // Can't easily test actual network changes in unit tests
        // but we can verify the properties exist and return values
        let isConnected = await NetworkMonitor.shared.isConnected
        let isExpensive = await NetworkMonitor.shared.isExpensive
        
        XCTAssertNotNil(isConnected)
        XCTAssertNotNil(isExpensive)
    }
}