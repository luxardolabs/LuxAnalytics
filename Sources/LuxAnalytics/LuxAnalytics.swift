import Foundation
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

/// Main analytics tracking class
/// This class must be initialized with a configuration before use
public final class LuxAnalytics: Sendable {
    /// Thread-safe storage for shared instance
    internal static let lock = NSLock()
    nonisolated(unsafe) internal static var _instance: LuxAnalytics?
    
    /// URLSession with certificate pinning (if configured)
    private static var urlSession: URLSession {
        let config = LuxAnalyticsConfiguration.current
        return URLSession.analyticsSession(with: config?.certificatePinning)
    }
    
    /// Shared instance - only available after initialization
    public static var shared: LuxAnalytics {
        lock.lock()
        defer { lock.unlock() }
        
        guard let instance = _instance else {
            // Provide helpful debugging info
            let callStack = Thread.callStackSymbols.prefix(10).joined(separator: "\n")
            fatalError("""
                
                ⚠️ LuxAnalytics.initialize() must be called before accessing shared instance.
                
                This usually happens when:
                1. A @StateObject initializer uses LuxAnalytics
                2. A static property initializes before your App.init()
                3. A singleton's init() method tracks analytics
                
                Fix: Move LuxAnalytics.initialize() earlier in your app lifecycle.
                See: https://github.com/luxardolabs/LuxAnalytics#initialization-order
                
                Call stack:
                \(callStack)
                """)
        }
        return instance
    }
    
    /// Internal access for extensions
    internal static var _shared: LuxAnalytics? {
        lock.lock()
        defer { lock.unlock() }
        return _instance
    }
    
    private let analyticsActor: AnalyticsActor
    
    /// Initialize LuxAnalytics with configuration
    /// - Parameter configuration: The analytics configuration
    /// - Throws: Throws if already initialized
    public static func initialize(with configuration: LuxAnalyticsConfiguration) throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard _instance == nil else {
            throw LuxAnalyticsError.alreadyInitialized
        }
        
        LuxAnalyticsConfiguration.current = configuration
        _instance = LuxAnalytics(configuration: configuration)
    }
    
    /// Check if LuxAnalytics is initialized
    public static var isInitialized: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _instance != nil
    }
    
    private init(configuration: LuxAnalyticsConfiguration) {
        self.analyticsActor = AnalyticsActor(configuration: configuration)
        Task {
            await analyticsActor.setupAutoFlush()
            await analyticsActor.setupAppLifecycleObservers()
        }
    }
    
    deinit {
        // Cleanup is handled by the actor's own lifecycle
    }
    
    // MARK: - Public API
    
    
    public func setUser(_ userId: String?) {
        Task {
            await analyticsActor.setUser(userId)
        }
    }
    
    public func setSession(_ sessionId: String?) {
        Task {
            await analyticsActor.setSession(sessionId)
        }
    }

    public func track(_ name: String, metadata: [String: String] = [:]) async throws {
        guard await AnalyticsSettings.shared.isEnabled else {
            await analyticsActor.debugLog("Analytics disabled, skipping event: \(name)")
            throw LuxAnalyticsError.analyticsDisabled
        }
        
        guard let config = LuxAnalyticsConfiguration.current else {
            await analyticsActor.debugLog("No configuration set, skipping event: \(name)")
            throw LuxAnalyticsError.notInitialized
        }

        var merged = await AppAnalyticsContext.shared.current()
        metadata.forEach { merged[$0] = $1 }

        let event = AnalyticsEvent(
            name: name,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            userId: await analyticsActor.getUserId(),
            sessionId: await analyticsActor.getSessionId(),
            metadata: merged
        )

        await analyticsActor.debugLog("Tracking event: \(name) - queuing for batch")
        
        // Always queue events for batching - never send immediately
        await LuxAnalyticsQueue.shared.enqueue(event)
        
        // Notify via async stream
        await Self.notifyEventQueued(event)
        
        // Auto-flush if queue is getting full
        if await LuxAnalyticsQueue.shared.queueSize >= config.maxQueueSize {
            await analyticsActor.debugLog("Queue size reached max, flushing batch")
            Task {
                await Self.flushAsync()
            }
        }
    }
    
    // MARK: - Flush Methods
    
    // Modern async/await API
    public static func flushAsync() async {
        guard let instance = _shared else { return }
        guard await AnalyticsSettings.shared.isEnabled else { return }
        guard let config = LuxAnalyticsConfiguration.current else { return }
        
        await instance.analyticsActor.debugLog("Async flush requested")
        
        // Record flush start time for metrics
        let startTime = Date()
        await LuxAnalyticsQueue.shared.flushBatch(using: _sendBatchAsync, batchSize: config.batchSize)
        let duration = Date().timeIntervalSince(startTime)
        
        // Record metrics
        await LuxAnalyticsDiagnostics.shared.recordFlushDuration(duration)
    }
    
    
    // MARK: - Network Implementation
    
    // Modern async implementation
    private static func _sendBatchAsync(_ events: [AnalyticsEvent]) async -> Bool {
        guard let config = LuxAnalyticsConfiguration.current else { return false }
        return await sendEventsWithCircuitBreaker(events, asBatch: true, config: config)
    }
    
    static func _sendEventsAsync(_ events: [AnalyticsEvent], asBatch: Bool, config: LuxAnalyticsConfiguration) async -> Bool {
        guard let instance = _shared else { return false }
        
        let payload: Data
        
        if asBatch && events.count > 1 {
            let batchPayload = ["events": events]
            guard let data = JSONCoders.encode(batchPayload) else {
                await instance.analyticsActor.debugLog("Failed to encode batch payload")
                return false
            }
            payload = data
        } else {
            guard let firstEvent = events.first,
                  let data = JSONCoders.encode(firstEvent) else {
                await instance.analyticsActor.debugLog("Failed to encode single event payload")
                return false
            }
            payload = data
        }

        // Compress payload if enabled and above threshold
        let finalPayload: Data
        var isCompressed = false
        
        if config.compressionEnabled && payload.count >= config.compressionThreshold {
            let compressionStart = Date()
            if let compressed = try? (payload as NSData).compressed(using: .zlib) as Data {
                finalPayload = compressed
                isCompressed = true
                let compressionDuration = Date().timeIntervalSince(compressionStart)
                await LuxAnalyticsDiagnostics.shared.recordCompressionTime(compressionDuration)
                await instance.analyticsActor.debugLog("Compressed payload from \(payload.count) to \(compressed.count) bytes")
            } else {
                finalPayload = payload
            }
        } else {
            finalPayload = payload
        }
        
        let timestamp = String(Int(Date().timeIntervalSince1970))
        
        let key = SymmetricKey(data: Data(config.hmacSecret.utf8))
        let message = finalPayload + Data(timestamp.utf8)
        let mac = HMAC<SHA256>.authenticationCode(for: message, using: key)
        let signature = Data(mac).map { String(format: "%02x", $0) }.joined()

        var req = URLRequest(url: config.apiURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if isCompressed {
            req.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
        }
        req.setValue(signature, forHTTPHeaderField: "X-HMAC-Signature")
        req.setValue(config.keyID, forHTTPHeaderField: "X-Key-ID")
        req.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        req.httpBody = finalPayload
        req.timeoutInterval = config.requestTimeout

        await instance.analyticsActor.debugLog("Sending \(asBatch ? "batch" : "single") request with \(events.count) event(s)")
        
        // Record payload size metrics
        await LuxAnalyticsDiagnostics.shared.recordPayloadSize(
            payload.count,
            compressedSize: isCompressed ? finalPayload.count : nil
        )

        do {
            let (data, response) = try await urlSession.data(for: req)
            
            if let http = response as? HTTPURLResponse {
                let success = (200..<300).contains(http.statusCode)
                if success {
                    await instance.analyticsActor.debugLog("Successfully sent \(events.count) event(s)")
                    // Record success metrics
                    await LuxAnalyticsDiagnostics.shared.recordEventsSent(count: events.count)
                    if asBatch {
                        await LuxAnalyticsDiagnostics.shared.recordBatchSent()
                    }
                } else {
                    await instance.analyticsActor.debugLog("Server error: HTTP \(http.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        await instance.analyticsActor.debugLog("Response: \(responseString)")
                    }
                    // Record failure metrics
                    await LuxAnalyticsDiagnostics.shared.recordEventsFailed(count: events.count)
                    if asBatch {
                        await LuxAnalyticsDiagnostics.shared.recordBatchFailed()
                    }
                }
                return success
            }
            return false
        } catch {
            await instance.analyticsActor.debugLog("Network error: \(error.localizedDescription)")
            // Record failure metrics
            await LuxAnalyticsDiagnostics.shared.recordEventsFailed(count: events.count)
            if asBatch {
                await LuxAnalyticsDiagnostics.shared.recordBatchFailed()
            }
            return false
        }
    }
    
    // MARK: - Queue Monitoring
    
    /// Get current queue statistics
    public static func getQueueStats() async -> QueueStats? {
        guard isInitialized else { return nil }
        return await LuxAnalyticsQueue.shared.getQueueStats()
    }
    
    /// Clear the event queue (use with caution)
    public static func clearQueue() async {
        guard isInitialized else { return }
        await LuxAnalyticsQueue.shared.clear()
    }
    
    /// Check if network is available
    public static func isNetworkAvailable() async -> Bool {
        return await NetworkMonitor.shared.isConnected
    }
}