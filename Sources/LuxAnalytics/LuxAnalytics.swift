import Foundation
import CryptoKit
import UIKit

public final class LuxAnalytics {
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

        debugLog("Tracking event: \(name)")
        
        if !LuxAnalytics._send(event) {
            debugLog("Failed to send event \(name), adding to queue")
            LuxAnalyticsQueue.shared.enqueue(event)
            
            // Auto-flush if queue is getting full
            if LuxAnalyticsQueue.shared.queueSize >= Config.maxQueueSize {
                debugLog("Queue size (\(LuxAnalyticsQueue.shared.queueSize)) reached max (\(Config.maxQueueSize)), flushing")
                LuxAnalytics.flush()
            }
        }
    }

    public static func flush() {
        guard AnalyticsSettings.shared.isEnabled else { return }
        Self.shared.debugLog("Manual flush requested")  // ← Fixed: Self.shared instead of shared
        LuxAnalyticsQueue.shared.flushBatch(using: _sendBatch, batchSize: Config.batchSize)
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
            Self.shared.debugLog("Auto-flush timer triggered")  // ← Fixed: Self.shared
            LuxAnalytics.flush()
        }
        debugLog("Auto-flush timer set to \(Config.autoFlushInterval) seconds")
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Self.shared.debugLog("App entering background, flushing events")  // ← Fixed: Self.shared
            LuxAnalytics.flush()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Self.shared.debugLog("App terminating, flushing events")  // ← Fixed: Self.shared
            LuxAnalytics.flush()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Optional: flush any queued events when app becomes active
            if LuxAnalyticsQueue.shared.queueSize > 0 {
                Self.shared.debugLog("App became active with \(LuxAnalyticsQueue.shared.queueSize) queued events, flushing")  // ← Fixed: Self.shared
                LuxAnalytics.flush()
            }
        }
    }
    
    private func debugLog(_ message: String) {
        guard Config.isDebugLoggingEnabled else { return }
        print("[LuxAnalytics] \(message)")
    }

    // MARK: - Network Implementation

    internal static func _send(_ event: AnalyticsEvent) -> Bool {
        return _sendEvents([event], asBatch: false)
    }
    
    internal static func _sendBatch(_ events: [AnalyticsEvent]) -> Bool {
        return _sendEvents(events, asBatch: true)
    }
    
    private static func _sendEvents(_ events: [AnalyticsEvent], asBatch: Bool) -> Bool {
        let payload: Data
        
        if asBatch && events.count > 1 {
            let batchPayload = ["events": events]
            guard let data = try? JSONEncoder().encode(batchPayload) else { 
                Self.shared.debugLog("Failed to encode batch payload")  // ← Fixed: Self.shared
                return false 
            }
            payload = data
        } else {
            guard let data = try? JSONEncoder().encode(events.first!) else { 
                Self.shared.debugLog("Failed to encode single event payload")  // ← Fixed: Self.shared
                return false 
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

        Self.shared.debugLog("Sending \(asBatch ? "batch" : "single") request with \(events.count) event(s)")  // ← Fixed: Self.shared

        let sema = DispatchSemaphore(value: 0)
        var success = false

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error {
                Self.shared.debugLog("Network error: \(error.localizedDescription)")  // ← Fixed: Self.shared
            } else if let http = response as? HTTPURLResponse {
                success = (200..<300).contains(http.statusCode)
                if success {
                    Self.shared.debugLog("Successfully sent \(events.count) event(s)")  // ← Fixed: Self.shared
                } else {
                    Self.shared.debugLog("Server error: HTTP \(http.statusCode)")  // ← Fixed: Self.shared
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        Self.shared.debugLog("Response: \(responseString)")  // ← Fixed: Self.shared
                    }
                }
            }
            sema.signal()
        }.resume()

        _ = sema.wait(timeout: .now() + Config.requestTimeout + 1.0)
        return success
    }
}
