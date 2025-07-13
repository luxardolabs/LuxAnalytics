import Foundation
import BackgroundTasks
#if canImport(UIKit)
import UIKit
#endif

/// Manages background task scheduling for analytics
@MainActor
public final class BackgroundTaskManager {
    
    /// Background task identifier
    public static let taskIdentifier = "com.luxardolabs.LuxAnalytics.flush"
    
    /// Shared instance
    public static let shared = BackgroundTaskManager()
    
    private init() {}
    
    /// Register background tasks (call from AppDelegate)
    public func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundTask(task)
        }
    }
    
    /// Schedule a background task
    public func scheduleBackgroundFlush() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        // Try to run within the next hour
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            SecureLogger.log("Failed to schedule background task: \(error)", category: .error, level: .error)
        }
    }
    
    /// Cancel pending background tasks
    public func cancelBackgroundTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
    }
    
    private func handleBackgroundTask(_ task: BGTask) {
        // Schedule next background task
        scheduleBackgroundFlush()
        
        // Create a background task for analytics flush
        let flushTask = Task {
            await LuxAnalytics.flush()
            task.setTaskCompleted(success: true)
        }
        
        // Handle expiration
        task.expirationHandler = {
            flushTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}

// MARK: - App Lifecycle Integration

extension BackgroundTaskManager {
    
    /// Setup background task handling (call from AppDelegate)
    public func setupBackgroundHandling() {
        // Register background tasks
        registerBackgroundTasks()
    }
    
    /// Run a simple background task with UIApplication beginBackgroundTask
    public func runBackgroundTask(_ work: @escaping () async -> Void) async {
        #if canImport(UIKit)
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        
        backgroundTaskID = await UIApplication.shared.beginBackgroundTask(withName: "LuxAnalytics.flush") {
            // Expiration handler
            Task { @MainActor in
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
            }
        }
        
        // Perform the work
        await work()
        
        // End the background task
        await MainActor.run {
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
        }
        #else
        // On non-iOS platforms, just run the work directly
        await work()
        #endif
    }
}

// MARK: - Background Processing

extension LuxAnalytics {
    
    /// Enable background task processing
    @MainActor
    public static func enableBackgroundProcessing() {
        BackgroundTaskManager.shared.setupBackgroundHandling()
    }
}