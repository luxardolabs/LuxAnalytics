import Foundation

// Compatibility helpers to prevent common migration mistakes
extension LuxAnalytics {
    
    /// Set user ID (synchronous) - provided for clarity
    /// - Note: This method is synchronous and does not require await
    @available(*, deprecated, renamed: "setUser", message: "Use setUser (no await needed)")
    public func setUserAsync(_ userId: String?) async {
        setUser(userId)
    }
    
    /// Set session ID (synchronous) - provided for clarity  
    /// - Note: This method is synchronous and does not require await
    @available(*, deprecated, renamed: "setSession", message: "Use setSession (no await needed)")
    public func setSessionAsync(_ sessionId: String?) async {
        setSession(sessionId)
    }
    
    /// Track event with old property name
    @available(*, deprecated, message: "Use track(_:metadata:) instead")
    public func track(_ name: String, properties: [String: String] = [:]) async throws {
        try await track(name, metadata: properties)
    }
}

// Static helper to make initialization more discoverable
extension LuxAnalytics {
    
    /// Configure and initialize LuxAnalytics in one call
    /// Useful for simple configurations
    public static func quickStart(
        apiURL: URL,
        hmacSecret: String,
        keyID: String,
        debugLogging: Bool = false
    ) throws {
        let config = LuxAnalyticsConfiguration(
            apiURL: apiURL,
            hmacSecret: hmacSecret,
            keyID: keyID,
            debugLogging: debugLogging
        )
        try initialize(with: config)
    }
}