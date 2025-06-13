import Foundation

public final class LuxAnalyticsQueue: Sendable {
    public static let shared = LuxAnalyticsQueue()
    private let queueKey = "lux_event_queue"
    private let lock = NSLock()

    private init() {}

    public var queueSize: Int {
        lock.lock()
        defer { lock.unlock() }
        return getQueue()?.count ?? 0
    }

    public func enqueue(_ event: AnalyticsEvent) {
        lock.lock()
        defer { lock.unlock() }
        
        var queue = getQueue() ?? []
        queue.append(event)
        save(queue)
    }

    // Legacy method for backwards compatibility
    public func flush(using send: @escaping (AnalyticsEvent) async -> Bool) async {
        lock.lock()
        guard let queue = getQueue(), !queue.isEmpty else {
            lock.unlock()
            return
        }
        let eventsToProcess = queue
        lock.unlock()

        var sent: [AnalyticsEvent] = []
        var failed: [AnalyticsEvent] = []
        
        for event in eventsToProcess {
            let success = await send(event)
            if success {
                sent.append(event)
            } else {
                failed.append(event)
            }
        }
        
        lock.lock()
        save(failed)
        lock.unlock()
    }

    public func flushBatch(using sendBatch: @escaping ([AnalyticsEvent]) async -> Bool, batchSize: Int = 10) async {
        lock.lock()
        guard let queue = getQueue(), !queue.isEmpty else {
            lock.unlock()
            return
        }
        let eventsToProcess = queue
        lock.unlock()

        var remaining = eventsToProcess
        var failedEvents: [AnalyticsEvent] = []
        
        while !remaining.isEmpty {
            let batch = Array(remaining.prefix(batchSize))
            remaining = Array(remaining.dropFirst(batchSize))
            
            let success = await sendBatch(batch)
            if !success {
                // Failed - collect this batch and all remaining as failed
                failedEvents.append(contentsOf: batch)
                failedEvents.append(contentsOf: remaining)
                break
            }
        }
        
        lock.lock()
        save(failedEvents)
        lock.unlock()
    }

    // iOS 15+ async variant
    @available(iOS 15.0, *)
    public func flushAsync(using sendBatch: @escaping ([AnalyticsEvent]) async -> Bool, batchSize: Int = 10) async {
        await flushBatch(using: sendBatch, batchSize: batchSize)
    }

    // Background queue variant for older iOS versions
    public func flushBackground(using sendBatch: @escaping ([AnalyticsEvent], @escaping (Bool) -> Void) -> Void, batchSize: Int = 10, completion: @escaping () -> Void = {}) {
        lock.lock()
        guard let queue = getQueue(), !queue.isEmpty else {
            lock.unlock()
            completion()
            return
        }
        let eventsToProcess = queue
        lock.unlock()

        var remaining = eventsToProcess
        var failedEvents: [AnalyticsEvent] = []
        let group = DispatchGroup()
        let failedLock = NSLock()
        
        func processBatch() {
            guard !remaining.isEmpty else {
                // All done, save any failed events
                self.lock.lock()
                self.save(failedEvents)
                self.lock.unlock()
                completion()
                return
            }
            
            let batch = Array(remaining.prefix(batchSize))
            remaining = Array(remaining.dropFirst(batchSize))
            
            group.enter()
            sendBatch(batch) { success in
                if !success {
                    failedLock.lock()
                    failedEvents.append(contentsOf: batch)
                    failedEvents.append(contentsOf: remaining)
                    remaining = [] // Stop processing
                    failedLock.unlock()
                }
                group.leave()
            }
            
            group.notify(queue: .global(qos: .utility)) {
                processBatch()
            }
        }
        
        DispatchQueue.global(qos: .utility).async {
            processBatch()
        }
    }

    private func getQueue() -> [AnalyticsEvent]? {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let decoded = try? JSONDecoder().decode([AnalyticsEvent].self, from: data) else {
            return nil
        }
        return decoded
    }

    private func save(_ queue: [AnalyticsEvent]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }
}

private extension Array {
    func partitioned(by predicate: (Element) -> Bool) -> ([Element], [Element]) {
        var matched: [Element] = []
        var unmatched: [Element] = []
        for e in self {
            if predicate(e) { matched.append(e) }
            else { unmatched.append(e) }
        }
        return (matched, unmatched)
    }
}
