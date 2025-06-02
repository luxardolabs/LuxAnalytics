import Foundation
import CryptoKit

public final class LuxAnalytics {
    public static let shared = LuxAnalytics()
    private var currentUserId: String?
    private var currentSessionId: String?
    
    public func setUser(_ userId: String?) {
        self.currentUserId = userId
    }
    
    public func setSession(_ sessionId: String?) {
        self.currentSessionId = sessionId
    }

    public func track(_ name: String, metadata: [String: String] = [:]) {
        guard AnalyticsSettings.shared.isEnabled else { return }

        var merged = AppAnalyticsContext.shared
        metadata.forEach { merged[$0] = $1 }

        let event = AnalyticsEvent(
            name: name,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            userId: currentUserId,
            sessionId: currentSessionId,
            metadata: merged
        )

        if !LuxAnalytics._send(event) {
            LuxAnalyticsQueue.shared.enqueue(event)
        }
    }

    public static func flush() {
        guard AnalyticsSettings.shared.isEnabled else { return }
        LuxAnalyticsQueue.shared.flushBatch(using: _sendBatch)
    }

    // Keep single event method
    internal static func _send(_ event: AnalyticsEvent) -> Bool {
        return _sendEvents([event], asBatch: false)
    }
    
    // New batch method
    internal static func _sendBatch(_ events: [AnalyticsEvent]) -> Bool {
        return _sendEvents(events, asBatch: true)
    }
    
    private static func _sendEvents(_ events: [AnalyticsEvent], asBatch: Bool) -> Bool {
        let payload: Data
        
        if asBatch && events.count > 1 {
            // Send as batch: {"events": [...]}
            let batchPayload = ["events": events]
            guard let data = try? JSONEncoder().encode(batchPayload) else { return false }
            payload = data
        } else {
            // Send as single event
            guard let data = try? JSONEncoder().encode(events.first!) else { return false }
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

        let sema = DispatchSemaphore(value: 0)
        var success = false

        URLSession.shared.dataTask(with: req) { _, res, _ in
            if let http = res as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                success = true
            }
            sema.signal()
        }.resume()

        _ = sema.wait(timeout: .now() + 2)
        return success
    }
}