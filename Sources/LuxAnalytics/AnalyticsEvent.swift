import Foundation

public struct AnalyticsEvent: Codable, Sendable {
    public let name: String
    public let timestamp: String
    public let userId: String?
    public let sessionId: String?
    public let metadata: [String: String]
    
    public init(name: String, timestamp: String, userId: String?, sessionId: String?, metadata: [String: String]) {
        self.name = name
        self.timestamp = timestamp
        self.userId = userId
        self.sessionId = sessionId
        self.metadata = metadata
    }
    
    enum CodingKeys: String, CodingKey {
        case name, timestamp, metadata
        case userId = "user_id"
        case sessionId = "session_id"
    }
}
