import Foundation

/// Strategy for handling queue overflow
public enum QueueOverflowStrategy: String, Codable, Sendable {
    /// Drop oldest events when queue is full
    case dropOldest
    
    /// Drop newest events when queue is full
    case dropNewest
    
    /// Drop all events and start fresh
    case dropAll
}

/// Configuration for LuxAnalytics initialization
public struct LuxAnalyticsConfiguration: Sendable {
    /// The analytics API endpoint URL
    public let apiURL: URL
    
    /// The HMAC secret key for request signing
    public let hmacSecret: String
    
    /// The API key identifier
    public let keyID: String
    
    /// Auto-flush interval in seconds (default: see LuxAnalyticsDefaults)
    public let autoFlushInterval: TimeInterval
    
    /// Maximum queue size before forced flush (default: see LuxAnalyticsDefaults)
    public let maxQueueSize: Int
    
    /// Number of events per batch (default: see LuxAnalyticsDefaults)
    public let batchSize: Int
    
    /// Enable debug logging (default: see LuxAnalyticsDefaults)
    public let debugLogging: Bool
    
    /// Network request timeout in seconds (default: see LuxAnalyticsDefaults)
    public let requestTimeout: TimeInterval
    
    /// Maximum queue size before dropping oldest events (default: see LuxAnalyticsDefaults)
    public let maxQueueSizeHard: Int
    
    /// Event time-to-live in seconds (default: see LuxAnalyticsDefaults)
    public let eventTTL: TimeInterval
    
    /// Maximum retry attempts for failed events (default: see LuxAnalyticsDefaults)
    public let maxRetryAttempts: Int
    
    /// Queue overflow strategy when hard limit is reached
    public let overflowStrategy: QueueOverflowStrategy
    
    /// Enable compression for payloads
    public let compressionEnabled: Bool
    
    /// Minimum payload size for compression
    public let compressionThreshold: Int
    
    /// Certificate pinning configuration (optional)
    public let certificatePinning: CertificatePinningConfig?
    
    /// Initializes a new configuration with explicit values
    /// - Parameters:
    ///   - apiURL: The analytics API endpoint URL
    ///   - hmacSecret: The HMAC secret key for request signing
    ///   - keyID: The API key identifier
    ///   - autoFlushInterval: Auto-flush interval in seconds
    ///   - maxQueueSize: Maximum queue size before forced flush
    ///   - batchSize: Number of events per batch
    ///   - debugLogging: Enable debug logging
    ///   - requestTimeout: Network request timeout in seconds
    ///   - maxQueueSizeHard: Maximum queue size before dropping events
    ///   - eventTTL: Event time-to-live in seconds
    ///   - maxRetryAttempts: Maximum retry attempts
    ///   - overflowStrategy: Strategy when queue is full
    public init(
        apiURL: URL,
        hmacSecret: String,
        keyID: String,
        autoFlushInterval: TimeInterval = LuxAnalyticsDefaults.autoFlushInterval,
        maxQueueSize: Int = LuxAnalyticsDefaults.maxQueueSize,
        batchSize: Int = LuxAnalyticsDefaults.batchSize,
        debugLogging: Bool = LuxAnalyticsDefaults.debugLogging,
        requestTimeout: TimeInterval = LuxAnalyticsDefaults.requestTimeout,
        maxQueueSizeHard: Int = LuxAnalyticsDefaults.maxQueueSizeHard,
        eventTTL: TimeInterval = LuxAnalyticsDefaults.eventTTL,
        maxRetryAttempts: Int = LuxAnalyticsDefaults.maxRetryAttempts,
        overflowStrategy: QueueOverflowStrategy = LuxAnalyticsDefaults.overflowStrategy,
        compressionEnabled: Bool = LuxAnalyticsDefaults.compressionEnabled,
        compressionThreshold: Int = LuxAnalyticsDefaults.compressionThreshold,
        certificatePinning: CertificatePinningConfig? = nil
    ) {
        self.apiURL = apiURL
        self.hmacSecret = hmacSecret
        self.keyID = keyID
        self.autoFlushInterval = autoFlushInterval
        self.maxQueueSize = maxQueueSize
        self.batchSize = batchSize
        self.debugLogging = debugLogging
        self.requestTimeout = requestTimeout
        self.maxQueueSizeHard = maxQueueSizeHard
        self.eventTTL = eventTTL
        self.maxRetryAttempts = maxRetryAttempts
        self.overflowStrategy = overflowStrategy
        self.compressionEnabled = compressionEnabled
        self.compressionThreshold = compressionThreshold
        self.certificatePinning = certificatePinning
    }
}

// MARK: - Configuration Storage
extension LuxAnalyticsConfiguration {
    /// Thread-safe storage for the current configuration
    private static let configurationLock = NSLock()
    nonisolated(unsafe) private static var _current: LuxAnalyticsConfiguration?
    
    /// The current configuration (thread-safe)
    internal static var current: LuxAnalyticsConfiguration? {
        get {
            configurationLock.lock()
            defer { configurationLock.unlock() }
            return _current
        }
        set {
            configurationLock.lock()
            defer { configurationLock.unlock() }
            _current = newValue
        }
    }
}