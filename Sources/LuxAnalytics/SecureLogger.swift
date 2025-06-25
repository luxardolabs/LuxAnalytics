import Foundation
import os.log

/// Secure logging that automatically redacts sensitive information
public enum SecureLogger {
    
    /// Log subsystem for LuxAnalytics
    private static let subsystem = "com.luxardolabs.LuxAnalytics"
    
    /// Log categories
    public enum Category: String {
        case general = "General"
        case network = "Network"
        case queue = "Queue"
        case configuration = "Configuration"
        case error = "Error"
        case performance = "Performance"
        
        var osLog: OSLog {
            return OSLog(subsystem: SecureLogger.subsystem, category: self.rawValue)
        }
    }
    
    /// Log levels
    public enum Level {
        case debug
        case info
        case error
        case fault
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .error: return .error
            case .fault: return .fault
            }
        }
    }
    
    /// Redact sensitive information from a string
    static func redact(_ string: String) -> String {
        var redacted = string
        
        // Use PII filter to sanitize
        redacted = PIIFilter.sanitize(redacted)
        
        // Additional patterns specific to our SDK
        
        // Redact HMAC secrets (any hex string > 32 chars)
        redacted = redacted.replacingOccurrences(
            of: #"\b[a-fA-F0-9]{32,}\b"#,
            with: "[HMAC_SECRET]",
            options: .regularExpression
        )
        
        // Redact API keys
        redacted = redacted.replacingOccurrences(
            of: #"\b(api[_-]?key|key[_-]?id)\s*[:=]\s*[\"']?([^\"'\s]+)[\"']?"#,
            with: "$1=[REDACTED]",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Redact URLs with credentials
        redacted = redacted.replacingOccurrences(
            of: #"(https?://)([^:]+):([^@]+)@"#,
            with: "$1[REDACTED]:[REDACTED]@",
            options: .regularExpression
        )
        
        // Redact user IDs (UUIDs)
        redacted = redacted.replacingOccurrences(
            of: #"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b"#,
            with: "[UUID]",
            options: .regularExpression
        )
        
        return redacted
    }
    
    /// Log a message with automatic redaction
    public static func log(
        _ message: String,
        category: Category = .general,
        level: Level = .debug,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let redactedMessage = redact(message)
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        
        if LuxAnalyticsConfiguration.current?.debugLogging == true {
            os_log(
                "%{public}@ [%{public}@:%{public}d] %{public}@",
                log: category.osLog,
                type: level.osLogType,
                fileName,
                function,
                line,
                redactedMessage
            )
        } else if level == .error || level == .fault {
            // Always log errors, even if debug logging is off
            os_log(
                "%{public}@",
                log: category.osLog,
                type: level.osLogType,
                redactedMessage
            )
        }
    }
    
    /// Log with formatting
    public static func log(
        _ format: String,
        _ args: CVarArg...,
        category: Category = .general,
        level: Level = .debug,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = String(format: format, arguments: args)
        log(message, category: category, level: level, file: file, function: function, line: line)
    }
}

// MARK: - Actor Logging Extension

extension AnalyticsActor {
    func log(_ message: String, category: SecureLogger.Category = .general, level: SecureLogger.Level = .debug) {
        SecureLogger.log(message, category: category, level: level)
    }
}