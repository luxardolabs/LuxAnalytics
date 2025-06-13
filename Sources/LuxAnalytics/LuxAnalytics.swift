import Foundation
import CryptoKit
import UIKit

@MainActor
public final class LuxAnalytics: Sendable {
    public static let shared = LuxAnalytics()
    private var currentUserId: String?
    private var currentSessionId: String?
    private var flushTimer: Timer?
    
    // Configuration - can be overridden in Info.plist
    private struct Config {
        static let autoFlushInterval: TimeInterval = {
            if let interval = Bundle.main.object(forInfoDictionaryKey: "LUX_AUTO_FLUSH_INTERVAL") as? NSNumber {
                return TimeInterval(interval.doubleValue)
            }
            return 30.0 // Default: 30 seconds
        }()
        
        static let maxQueueSize: Int = {
            if let size = Bundle.main.object(forInfoDictionaryKey: "LUX_MAX_QUEUE_SIZE") as? NSNumber {
                return size.intValue
            }
            return 100 // Default: 100 events
        }()
        
        static let batchSize: Int = {
            if let size = Bundle.main.object(forInfoDictionaryKey: "LUX_BATCH_SIZE") as? NSNumber {
                return size.intValue
            }
            return 10 // Default: 10 events per batch
        }()
        
        static let isDebugLoggingEnabled: Bool = {
            if let enabled = Bundle.main.object(forInfoDictionaryKey: "LUX_DEBUG_LOGGING") as? NSNumber {
                return enabled.boolValue
            }
            return false // Default: disabled
        }()
        
        static let requestTimeout: TimeInterval = {
            if let timeout = Bundle.main.object(forInfoDictionaryKey: "LUX_REQUEST_TIMEOUT") as? NSNumber {
                return TimeInterval(timeout.doubleValue)
            }
            return 10.0 // Default: 10 seconds
        }()
    }
    
    private init() {
        setupAutoFlush()
        setupAppLifecycleObservers()
        debugLog("LuxAnalytics initialized with config: autoFlush=\(Config.autoFlushInterval)s, maxQueue=\(Config.maxQueueSize), batchSize=\(Config.batchSize)")
    }
    
    deinit {
        flushTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public API
    
    public func setUser(_ userId: String?) {
        self.currentUserId = userId
        debugLog("User set: \(userId ?? "nil")")
    }
    
    public func setSession(_ sessionId: String?) {
        self.currentSessionId = sessionId
        debugLog("Session set: \(sessionId ?? "nil")")
    }

    public func track(_ name: String, metadata: [String: String] = [:]) {
        guard AnalyticsSettings.shared.isEnabled else {
            debugLog("Analytics disabled, skipping event: \(name)")
            return
        }

        var merged = AppAnalyticsContext.shared
        metadata.forEach { merged[$0] = $1 }

        let event = AnalyticsEvent(
            name: name,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            userId: currentUserId,
            sessionId: currentSessionId,
            metadata: merged
        )

        debugLog("Tracking event: \(name) - queuing for batch")
        
        // Always queue events for batching - never send immediately
        LuxAnalyticsQueue.shared.enqueue(event)
        
        // Auto-flush if queue is getting full
        if LuxAnalyticsQueue.shared.queueSize >= Config.maxQueueSize {
            debugLog("Queue size (\(LuxAnalyticsQueue.shared.queueSize)) reached max (\(Config.maxQueueSize)), flushing batch")
            Task {
                await Self.flushAsync()
            }
        }
    }
    
    // MARK: - Flush Methods
    
    // Modern async/await API
    public static func flushAsync() async {
        guard await AnalyticsSettings.shared.isEnabled else { return }
        await shared.debugLogAsync("Async flush requested")
        await LuxAnalyticsQueue.shared.flushBatch(using: _sendBatchAsync, batchSize: Config.batchSize)
    }
    
    // Legacy flush for backwards compatibility
    public static func flush() {
        Task {
            await flushAsync()
        }
    }
    
    // Background flush for older iOS versions
    public static func flushBackground(completion: @escaping () -> Void = {}) {
        Task {
            guard await AnalyticsSettings.shared.isEnabled else {
                completion()
                return
            }
            await shared.debugLogAsync("Background flush requested")
            
            if #available(iOS 15.0, *) {
                await flushAsync()
                completion()
            } else {
                LuxAnalyticsQueue.shared.flushBackground(
                    using: _sendBatchBackground,
                    batchSize: Config.batchSize,
                    completion: completion
                )
            }
        }
    }
    
    public func enableDebugLogging(_ enabled: Bool) {
        debugLog("Debug logging is controlled via LUX_DEBUG_LOGGING in Info.plist")
    }
    
    // MARK: - Private Implementation
    
    private func setupAutoFlush() {
        guard Config.autoFlushInterval > 0 else {
            debugLog("Auto-flush disabled (interval = 0)")
            return
        }
        
        flushTimer = Timer.scheduledTimer(withTimeInterval: Config.autoFlushInterval, repeats: true) { _ in
            Task {
                await Self.shared.debugLogAsync("Auto-flush timer triggered")
                await Self.flushAsync()
            }
        }
        debugLog("Auto-flush timer set to \(Config.autoFlushInterval) seconds")
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await Self.shared.debugLogAsync("App entering background, flushing events")
                await Self.flushAsync()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            // For app termination, we need to wait briefly for flush
            let group = DispatchGroup()
            group.enter()
            
            Task {
                await Self.shared.debugLogAsync("App terminating, flushing events")
                await Self.flushAsync()
                group.leave()
            }
            
            // Wait up to 2 seconds for flush to complete
            _ = group.wait(timeout: .now() + 2.0)
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                if await LuxAnalyticsQueue.shared.queueSize > 0 {
                    await Self.shared.debugLogAsync("App became active with \(await LuxAnalyticsQueue.shared.queueSize) queued events, flushing")
                    await Self.flushAsync()
                }
            }
        }
    }
    
    private func debugLog(_ message: String) {
        guard Config.isDebugLoggingEnabled else { return }
        print("[LuxAnalytics] \(message)")
    }
    
    private func debugLogAsync(_ message: String) async {
        guard Config.isDebugLoggingEnabled else { return }
        await MainActor.run {
            print("[LuxAnalytics] \(message)")
        }
    }

    // MARK: - Network Implementation
    
    // Modern async/await network implementation
    private static func _sendBatchAsync(_ events: [AnalyticsEvent]) async -> Bool {
        return await _sendEventsAsync(events, asBatch: true)
    }
    
    private static func _sendEventAsync(_ event: AnalyticsEvent) async -> Bool {
        return await _sendEventsAsync([event], asBatch: false)
    }
    
    private static func _sendEventsAsync(_ events: [AnalyticsEvent], asBatch: Bool) async -> Bool {
        let payload: Data
        
        if asBatch && events.count > 1 {
            let batchPayload = ["events": events]
            guard let data = try? JSONEncoder().encode(batchPayload) else {
                await shared.debugLogAsync("Failed to encode batch payload")
                return false
            }
            payload = data
        } else {
            guard let data = try? JSONEncoder().encode(events.first!) else {
                await shared.debugLogAsync("Failed to encode single event payload")
                return false
            }
            payload = data
        }

        let timestamp = String(Int(Date().timeIntervalSince1970))
        
        let key = SymmetricKey(data: Data(await AnalyticsConfig.hmacSecret.utf8))
        let message = payload + Data(timestamp.utf8)
        let mac = HMAC<SHA256>.authenticationCode(for: message, using: key)
        let signature = Data(mac).map { String(format: "%02x", $0) }.joined()

        var req = URLRequest(url: await AnalyticsConfig.endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(signature, forHTTPHeaderField: "X-Signature")
        req.setValue(await AnalyticsConfig.keyId, forHTTPHeaderField: "X-Key-ID")
        req.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        req.httpBody = payload
        req.timeoutInterval = Config.requestTimeout

        await shared.debugLogAsync("Sending \(asBatch ? "batch" : "single") request with \(events.count) event(s)")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            
            if let http = response as? HTTPURLResponse {
                let success = (200..<300).contains(http.statusCode)
                if success {
                    await shared.debugLogAsync("Successfully sent \(events.count) event(s)")
                } else {
                    await shared.debugLogAsync("Server error: HTTP \(http.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        await shared.debugLogAsync("Response: \(responseString)")
                    }
                }
                return success
            }
            return false
        } catch {
            await shared.debugLogAsync("Network error: \(error.localizedDescription)")
            return false
        }
    }
    
    // Background implementation for older iOS versions
    private static func _sendBatchBackground(_ events: [AnalyticsEvent], completion: @escaping (Bool) -> Void) {
        _sendEventsBackground(events, asBatch: true, completion: completion)
    }
    
    private static func _sendEventsBackground(_ events: [AnalyticsEvent], asBatch: Bool, completion: @escaping (Bool) -> Void) {
        // Always perform network operations on background queue
        DispatchQueue.global(qos: .utility).async {
            let payload: Data
            
            if asBatch && events.count > 1 {
                let batchPayload = ["events": events]
                guard let data = try? JSONEncoder().encode(batchPayload) else {
                    DispatchQueue.main.async {
                        shared.debugLog("Failed to encode batch payload")
                        completion(false)
                    }
                    return
                }
                payload = data
            } else {
                guard let data = try? JSONEncoder().encode(events.first!) else {
                    DispatchQueue.main.async {
                        shared.debugLog("Failed to encode single event payload")
                        completion(false)
                    }
                    return
                }
                payload = data
            }

            let timestamp = String(Int(Date().timeIntervalSince1970))
            
            let key = SymmetricKey(data: Data(AnalyticsConfig.hmacSecret.utf8))
            let message = payload + Data(timestamp.utf8)
            let mac = HMAC<SHA256>.authenticationCode(for: message, using: key)
            let signature = Data(mac).map { String(format: "%02x", $0) }.joined()

            var req = URLRequest(url: AnalyticsConfig.endpoint)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(signature, forHTTPHeaderField: "X-Signature")
            req.setValue(AnalyticsConfig.keyId, forHTTPHeaderField: "X-Key-ID")
            req.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
            req.httpBody = payload
            req.timeoutInterval = Config.requestTimeout

            DispatchQueue.main.async {
                shared.debugLog("Sending \(asBatch ? "batch" : "single") request with \(events.count) event(s)")
            }

            URLSession.shared.dataTask(with: req) { data, response, error in
                var success = false
                
                if let error = error {
                    DispatchQueue.main.async {
                        shared.debugLog("Network error: \(error.localizedDescription)")
                    }
                } else if let http = response as? HTTPURLResponse {
                    success = (200..<300).contains(http.statusCode)
                    DispatchQueue.main.async {
                        if success {
                            shared.debugLog("Successfully sent \(events.count) event(s)")
                        } else {
                            shared.debugLog("Server error: HTTP \(http.statusCode)")
                            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                                shared.debugLog("Response: \(responseString)")
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    completion(success)
                }
            }.resume()
        }
    }
}
