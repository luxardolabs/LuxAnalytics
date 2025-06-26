import Foundation

// Alternative initialization pattern to prevent crashes
extension LuxAnalytics {
    
    /// Configuration holder for lazy initialization
    private static let configLock = NSLock()
    nonisolated(unsafe) private static var pendingConfiguration: LuxAnalyticsConfiguration?
    
    /// Set configuration for lazy initialization
    /// This allows configuration to be set early without full initialization
    public static func setPendingConfiguration(_ config: LuxAnalyticsConfiguration) {
        configLock.lock()
        defer { configLock.unlock() }
        pendingConfiguration = config
    }
    
    /// Alternative shared accessor with auto-initialization
    public static var lazyShared: LuxAnalytics {
        if let instance = _shared {
            return instance
        }
        
        // Try to auto-initialize with pending config
        configLock.lock()
        let config = pendingConfiguration
        configLock.unlock()
        
        if let config = config {
            do {
                try initialize(with: config)
                configLock.lock()
                pendingConfiguration = nil
                configLock.unlock()
                return _shared!
            } catch {
                fatalError("LuxAnalytics auto-initialization failed: \(error)")
            }
        }
        
        fatalError("LuxAnalytics.initialize() or setPendingConfiguration() must be called before accessing shared instance")
    }
    
    /// Safe shared accessor that returns nil if not initialized
    public static var sharedIfInitialized: LuxAnalytics? {
        return _shared
    }
}

// Example usage in README:
/*
 
 // Option 1: Set pending config early
 LuxAnalytics.setPendingConfiguration(config)
 // Later access will auto-initialize
 LuxAnalytics.lazyShared.track(...)
 
 // Option 2: Safe optional access
 LuxAnalytics.sharedIfInitialized?.track(...)
 
 */