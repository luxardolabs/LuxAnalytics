import Foundation

/// Errors that can occur in LuxAnalytics
public enum LuxAnalyticsError: LocalizedError {
    /// LuxAnalytics has already been initialized
    case alreadyInitialized
    
    /// LuxAnalytics has not been initialized
    case notInitialized
    
    /// Configuration is invalid
    case invalidConfiguration(String)
    
    /// Network error occurred
    case networkError(Error)
    
    /// Server returned an error
    case serverError(statusCode: Int, response: String?)
    
    /// Failed to encode event data
    case encodingError(Error)
    
    /// Queue operation failed
    case queueError(String)
    
    /// Analytics is disabled
    case analyticsDisabled
    
    public var errorDescription: String? {
        switch self {
        case .alreadyInitialized:
            return "LuxAnalytics has already been initialized"
        case .notInitialized:
            return "LuxAnalytics has not been initialized. Call LuxAnalytics.initialize() first"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let statusCode, let response):
            return "Server error (HTTP \(statusCode)): \(response ?? "No response")"
        case .encodingError(let error):
            return "Failed to encode data: \(error.localizedDescription)"
        case .queueError(let message):
            return "Queue error: \(message)"
        case .analyticsDisabled:
            return "Analytics is disabled"
        }
    }
}