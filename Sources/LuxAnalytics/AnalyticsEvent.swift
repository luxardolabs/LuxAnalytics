import Foundation

public struct AnalyticsEvent: Codable {
    public let name: String
    public let timestamp: String
    public let userId: String?
    public let sessionId: String?
    public let metadata: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case name, timestamp, metadata
        case userId = "user_id"
        case sessionId = "session_id"
    }
}