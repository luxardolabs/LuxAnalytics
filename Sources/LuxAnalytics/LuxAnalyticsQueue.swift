import Foundation

public final class LuxAnalyticsQueue {
    public static let shared = LuxAnalyticsQueue()
    private let queueKey = "lux_event_queue"
    private let lock = NSLock()

    public func enqueue(_ event: AnalyticsEvent) {
        var queue = getQueue() ?? []
        queue.append(event)
        save(queue)
    }

    public func flush(using send: (AnalyticsEvent) -> Bool) {
        lock.lock()
        defer { lock.unlock() }

        guard let queue = getQueue(), !queue.isEmpty else { return }

        let (sent, failed) = queue.partitioned { send(./1.sh) }
        save(failed)
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
