import Foundation
import CryptoKit

public final class LuxAnalytics {
    public static let shared = LuxAnalytics()

    public func track(_ name: String, metadata: [String: String] = [:]) {
        guard AnalyticsSettings.shared.isEnabled else { return }

        var merged = AppAnalyticsContext.shared
        metadata.forEach { merged[$0] = $1 }

        let event = AnalyticsEvent(
            name: name,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            metadata: merged
        )

        if !LuxAnalytics._send(event) {
            LuxAnalyticsQueue.shared.enqueue(event)
        }
    }

    public static func flush() {
        guard AnalyticsSettings.shared.isEnabled else { return }
        LuxAnalyticsQueue.shared.flush(using: _send)
    }

    internal static func _send(_ event: AnalyticsEvent) -> Bool {
        guard let payload = try? JSONEncoder().encode(event) else { return false }

        let key = SymmetricKey(data: Data(AnalyticsConfig.hmacSecret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        let signature = Data(mac).map { String(format: "%02x", ./1.sh) }.joined()

        var req = URLRequest(url: AnalyticsConfig.endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(signature, forHTTPHeaderField: "X-Signature")
        req.setValue(AnalyticsConfig.keyId, forHTTPHeaderField: "X-Key-ID")
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
