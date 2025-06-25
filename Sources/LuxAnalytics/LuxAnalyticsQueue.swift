import Foundation

/// Actor-based queue for thread-safe event management with retry logic
public actor LuxAnalyticsQueue {
    public static let shared = LuxAnalyticsQueue()
    private let queueKey = "com.luxardolabs.LuxAnalytics.eventQueue.v2"
    private let userDefaults: UserDefaults
    
    /// In-memory cache of the queue
    private var queueCache: [QueuedEvent] = []
    
    /// Track failed batch IDs to prevent infinite retries
    private var failedBatchIds: Set<String> = []
    
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        // Queue will be loaded on first access
        self.queueCache = []
        // Clean expired events on startup
        Task {
            await loadAndCleanQueue()
        }
    }
    
    private func loadAndCleanQueue() {
        self.queueCache = loadQueue() ?? []
        cleanExpiredEvents()
    }

    public var queueSize: Int {
        return queueCache.count
    }

    public func enqueue(_ event: AnalyticsEvent) {
        guard let config = LuxAnalyticsConfiguration.current else { return }
        
        let queuedEvent = QueuedEvent(event: event)
        
        // Check queue size limit
        if queueCache.count >= config.maxQueueSizeHard {
            handleQueueOverflow(config: config)
        }
        
        queueCache.append(queuedEvent)
        saveQueue()
    }

    // Batch flush with retry logic and network awareness
    public func flushBatch(using sendBatch: @escaping ([AnalyticsEvent]) async -> Bool, batchSize: Int) async {
        guard !queueCache.isEmpty else { return }
        guard let config = LuxAnalyticsConfiguration.current else { return }
        
        // Check network connectivity
        if await !NetworkMonitor.shared.isConnected {
            // If offline, clean expired events but don't attempt to send
            await cleanExpiredEvents()
            return
        }
        
        // Clean expired events first
        await cleanExpiredEvents()
        
        // Get events ready for retry
        let eventsToProcess = queueCache.filter { queuedEvent in
            queuedEvent.shouldRetry(maxRetries: config.maxRetryAttempts)
        }
        
        guard !eventsToProcess.isEmpty else { return }
        
        var updatedQueue: [QueuedEvent] = []
        var successCount = 0
        
        // Process in batches
        for index in stride(from: 0, to: eventsToProcess.count, by: batchSize) {
            let endIndex = min(index + batchSize, eventsToProcess.count)
            var batch = Array(eventsToProcess[index..<endIndex])
            
            // Generate batch ID for tracking
            let batchId = UUID().uuidString
            let events = batch.map { $0.event }
            
            // Skip if this batch has permanently failed before
            if failedBatchIds.contains(batchId) {
                updatedQueue.append(contentsOf: batch)
                continue
            }
            
            let success = await sendBatch(events)
            
            if success {
                successCount += batch.count
                // Don't add successful events back to queue
            } else {
                // Update retry metadata
                for i in 0..<batch.count {
                    batch[i].retryCount += 1
                    batch[i].lastRetryAt = Date()
                }
                
                // Check if any events have exceeded max retries
                let retriableEvents = batch.filter { $0.retryCount < config.maxRetryAttempts }
                let failedEvents = batch.filter { $0.retryCount >= config.maxRetryAttempts }
                
                if !failedEvents.isEmpty {
                    SecureLogger.log("Dropping \(failedEvents.count) events after max retries", category: .queue, level: .info)
                }
                
                updatedQueue.append(contentsOf: retriableEvents)
            }
        }
        
        // Add any events we didn't process (due to retry delays)
        let processedEventIds = Set(eventsToProcess.map { $0.event.id })
        let unprocessedEvents = queueCache.filter { !processedEventIds.contains($0.event.id) }
        updatedQueue.append(contentsOf: unprocessedEvents)
        
        // Update queue
        queueCache = updatedQueue
        saveQueue()
        
        if successCount > 0 {
            SecureLogger.log("Successfully sent \(successCount) events, \(queueCache.count) remaining in queue", category: .queue, level: .info)
        }
    }
    
    // MARK: - Queue Management
    
    private func cleanExpiredEvents() {
        guard let config = LuxAnalyticsConfiguration.current else { return }
        
        let before = queueCache.count
        let expiredEvents = queueCache.filter { $0.isExpired(ttlSeconds: config.eventTTL) }.map { $0.event }
        queueCache = queueCache.filter { !$0.isExpired(ttlSeconds: config.eventTTL) }
        let after = queueCache.count
        
        if before != after {
            saveQueue()
            SecureLogger.log("Cleaned \(before - after) expired events from queue", category: .queue, level: .info)
            if !expiredEvents.isEmpty {
                Task {
                    await LuxAnalytics.notifyEventsExpired(expiredEvents)
                }
            }
        }
    }
    
    private func handleQueueOverflow(config: LuxAnalyticsConfiguration) {
        switch config.overflowStrategy {
        case .dropOldest:
            // Remove oldest 20% of events
            let dropCount = max(1, queueCache.count / 5)
            queueCache.removeFirst(dropCount)
            SecureLogger.log("Queue overflow: dropped \(dropCount) oldest events", category: .queue, level: .info)
            Task {
                await LuxAnalytics.notifyEventsDropped(count: dropCount, reason: .dropOldest)
            }
            
        case .dropNewest:
            // Will drop the incoming event by not adding it
            SecureLogger.log("Queue overflow: dropping new event", category: .queue, level: .info)
            Task {
                await LuxAnalytics.notifyEventsDropped(count: 1, reason: .dropNewest)
            }
            
        case .dropAll:
            let count = queueCache.count
            queueCache.removeAll()
            SecureLogger.log("Queue overflow: cleared entire queue", category: .queue, level: .info)
            Task {
                await LuxAnalytics.notifyEventsDropped(count: count, reason: .dropAll)
            }
        }
    }

    // MARK: - Persistence
    
    private func loadQueue() -> [QueuedEvent]? {
        guard let encryptedData = userDefaults.data(forKey: queueKey) else {
            // Try to migrate from old queue format
            return migrateFromV1Queue()
        }
        
        // Try to decrypt
        guard let decryptedData = QueueEncryption.decrypt(encryptedData) else {
            // If decryption fails, try to read as unencrypted (migration case)
            if let events = JSONCoders.decode([QueuedEvent].self, from: encryptedData) {
                // Re-save as encrypted
                queueCache = events
                saveQueue()
                return events
            }
            return nil
        }
        
        return JSONCoders.decode([QueuedEvent].self, from: decryptedData)
    }
    
    private func migrateFromV1Queue() -> [QueuedEvent]? {
        let oldKey = "lux_event_queue"  // Keep old key for migration
        guard let data = userDefaults.data(forKey: oldKey),
              let oldEvents = JSONCoders.decode([AnalyticsEvent].self, from: data) else {
            return nil
        }
        
        // Convert old events to new format
        let queuedEvents = oldEvents.map { QueuedEvent(event: $0) }
        
        // Remove old data
        userDefaults.removeObject(forKey: oldKey)
        
        return queuedEvents
    }
    
    private func saveQueue() {
        guard let data = JSONCoders.encode(queueCache) else { return }
        
        // Encrypt before saving
        if let encryptedData = QueueEncryption.encrypt(data) {
            userDefaults.set(encryptedData, forKey: queueKey)
        } else {
            // Fallback to unencrypted if encryption fails
            userDefaults.set(data, forKey: queueKey)
        }
    }
    
    // MARK: - Monitoring
    
    public func getQueueStats() -> QueueStats {
        let totalEvents = queueCache.count
        let retriableEvents = queueCache.filter { 
            $0.retryCount < (LuxAnalyticsConfiguration.current?.maxRetryAttempts ?? LuxAnalyticsDefaults.maxRetryAttempts)
        }.count
        let expiredEvents = queueCache.filter {
            $0.isExpired(ttlSeconds: LuxAnalyticsConfiguration.current?.eventTTL ?? LuxAnalyticsDefaults.eventTTL)
        }.count
        
        return QueueStats(
            totalEvents: totalEvents,
            retriableEvents: retriableEvents,
            expiredEvents: expiredEvents,
            oldestEventAge: queueCache.first?.queuedAt.timeIntervalSinceNow ?? 0
        )
    }
    
    // Clear queue (for testing or cleanup)
    public func clear() {
        queueCache = []
        failedBatchIds.removeAll()
        userDefaults.removeObject(forKey: queueKey)
    }
}

/// Queue statistics for monitoring
public struct QueueStats: Codable, Sendable {
    public let totalEvents: Int
    public let retriableEvents: Int
    public let expiredEvents: Int
    public let oldestEventAge: TimeInterval
}