import Foundation

/// Debug utilities for troubleshooting initialization issues
public struct LuxAnalyticsDebug {
    
    /// Enable initialization debugging
    private static let debugLock = NSLock()
    nonisolated(unsafe) private static var _debugInitialization = false
    
    public static var debugInitialization: Bool {
        get {
            debugLock.lock()
            defer { debugLock.unlock() }
            return _debugInitialization
        }
        set {
            debugLock.lock()
            defer { debugLock.unlock() }
            _debugInitialization = newValue
        }
    }
    
    /// Track initialization attempts
    internal static func logInitAttempt(from: String = #function, file: String = #file, line: Int = #line) {
        guard debugInitialization else { return }
        print("""
            [LuxAnalytics Debug] Initialization attempt:
            - From: \(from)
            - File: \(file):\(line)
            - Thread: \(Thread.isMainThread ? "Main" : "Background")
            - Time: \(Date())
            """)
    }
    
    /// Track shared access attempts
    internal static func logSharedAccess(from: String = #function, file: String = #file, line: Int = #line) {
        guard debugInitialization else { return }
        print("""
            [LuxAnalytics Debug] Shared instance accessed:
            - From: \(from)
            - File: \(file):\(line)
            - Initialized: \(LuxAnalytics.isInitialized)
            - Thread: \(Thread.isMainThread ? "Main" : "Background")
            """)
    }
    
    /// Validate common setup issues
    public static func validateSetup() {
        print("""
            
            ========== LuxAnalytics Setup Validation ==========
            ✓ Checking initialization status...
              - Initialized: \(LuxAnalytics.isInitialized)
            
            ✓ Checking configuration...
              - Has current config: \(LuxAnalyticsConfiguration.current != nil)
            
            ✓ Checking queue status...
              - Queue accessible: \(LuxAnalytics.sharedIfInitialized != nil)
            
            ✓ Common issues to check:
              1. Is LuxAnalytics.initialize() called in App.init()?
              2. Is the initialization method static?
              3. Are StateObjects created AFTER initialization?
              4. Do any static properties use LuxAnalytics?
            
            For more help: https://github.com/luxardolabs/LuxAnalytics#troubleshooting
            ===================================================
            
            """)
    }
}