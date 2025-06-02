import Foundation

public struct AnalyticsEvent: Codable {
    public let name: String
    public let timestamp: String
    public let metadata: [String: String]
}
