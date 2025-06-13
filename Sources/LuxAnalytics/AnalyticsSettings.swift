import Foundation

public final class AnalyticsSettings: @unchecked Sendable {
    public static let shared = AnalyticsSettings()
    private let key = "lux_analytics_enabled"

    public var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    private init() {}
}
