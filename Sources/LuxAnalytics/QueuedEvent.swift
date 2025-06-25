import Foundation

/// Wrapper for queued events with metadata for retry and TTL management
struct QueuedEvent: Codable {
    let event: AnalyticsEvent
    let queuedAt: Date
    var retryCount: Int
    var lastRetryAt: Date?
    
    init(event: AnalyticsEvent) {
        self.event = event
        self.queuedAt = Date()
        self.retryCount = 0
        self.lastRetryAt = nil
    }
    
    /// Check if event has expired based on TTL
    func isExpired(ttlSeconds: TimeInterval) -> Bool {
        return Date().timeIntervalSince(queuedAt) > ttlSeconds
    }
    
    /// Calculate next retry delay using exponential backoff with jitter
    func nextRetryDelay() -> TimeInterval {
        let baseDelay = 2.0
        let maxDelay = 300.0 // 5 minutes max
        
        // Exponential backoff: 2^retryCount seconds
        let exponentialDelay = min(pow(baseDelay, Double(retryCount)), maxDelay)
        
        // Add jitter (±25%) to prevent thundering herd
        let jitter = exponentialDelay * 0.25
        let randomJitter = Double.random(in: -jitter...jitter)
        
        return exponentialDelay + randomJitter
    }
    
    /// Check if we should retry based on retry count and time since last retry
    func shouldRetry(maxRetries: Int) -> Bool {
        guard retryCount < maxRetries else { return false }
        
        if let lastRetry = lastRetryAt {
            let timeSinceLastRetry = Date().timeIntervalSince(lastRetry)
            return timeSinceLastRetry >= nextRetryDelay()
        }
        
        return true
    }
}