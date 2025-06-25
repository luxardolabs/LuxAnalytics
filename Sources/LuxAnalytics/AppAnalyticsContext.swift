import Foundation
#if canImport(UIKit)
import UIKit
#endif
import CryptoKit

public actor AppAnalyticsContext {
    static let shared = AppAnalyticsContext()
    
    // Cached context - only changes on app restart
    private var cachedContext: [String: String]?
    private var deviceID: String?
    
    private init() {}
    
    /// Get current analytics context (cached)
    public func current() async -> [String: String] {
        if let cached = cachedContext {
            return cached
        }
        
        // Generate context once and cache it
        let context = await generateContext()
        cachedContext = context
        return context
    }
    
    /// Force refresh the cached context (rarely needed)
    public func refresh() async {
        cachedContext = await generateContext()
    }
    
    private func generateContext() async -> [String: String] {
        let deviceId = await getOrCreateDeviceID()
        
        return await MainActor.run {
            let size = UIScreen.main.bounds
            return [
                "device_model": UIDevice.modelCode(),
                "device_type": UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone",
                "screen_resolution": "\(Int(size.width))x\(Int(size.height))",
                "system_version": UIDevice.current.systemVersion,
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
                "locale": Locale.current.identifier,
                "timezone": TimeZone.current.identifier,
                "device_id": deviceId,
                "is_testflight": Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "true" : "false"
            ]
        }
    }

    private func getOrCreateDeviceID() async -> String {
        if let cached = deviceID {
            return cached
        }
        
        let uuid = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString }
        guard let uuid = uuid else { 
            let fallback = "unknown"
            deviceID = fallback
            return fallback
        }
        
        let hash = SHA256.hash(data: Data(uuid.utf8))
        let id = hash.map { String(format: "%02x", $0) }.joined()
        deviceID = id
        return id
    }
}

extension UIDevice {
    /// Get device model code
    /// This is safe to call from any thread as it doesn't access UIKit
    nonisolated public static func modelCode() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}