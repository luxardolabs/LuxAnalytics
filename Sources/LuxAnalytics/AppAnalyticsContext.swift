import Foundation
import UIKit
import CryptoKit

public struct AppAnalyticsContext {
    public static var shared: [String: String] {
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
            "device_id": anonymizedDeviceID(),
            "is_testflight": Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "true" : "false"
        ]
    }

    private static func anonymizedDeviceID() -> String {
        guard let uuid = UIDevice.current.identifierForVendor?.uuidString else { return "unknown" }
        let hash = SHA256.hash(data: Data(uuid.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

extension UIDevice {
    public static func modelCode() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}